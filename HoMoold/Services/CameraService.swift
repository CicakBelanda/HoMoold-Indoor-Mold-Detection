//
//  CameraService.swift
//  HoMoold
//
//  Wrapper AVCaptureSession untuk rekam video sungguhan di layar "Rekam Video".
//  Selain merekam ke file (buat disimpan/preview), sesi ini juga jalanin dua
//  model YOLO (MoldDamp, WindowAC) secara live lewat AVCaptureVideoDataOutput,
//  buat nge-drive panduan adaptif (lihat GuidedRecordingController).
//
//  AVCaptureSession harus dikonfigurasi/dijalankan di luar main thread, tapi
//  CameraService sendiri @MainActor (buat @Published). Supaya closure di
//  background queue tidak menyentuh state main-actor-isolated, semua kerja
//  AVFoundation dipisah ke `SessionController` yang bukan actor-isolated sama
//  sekali.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class CameraService: ObservableObject {
    @Published var isSessionReady = false
    @Published var isRecording = false
    @Published var permissionDenied = false
    @Published var lastRecordedURL: URL?
    @Published var errorMessage: String?
    @Published var liveDetections: [LiveDetection] = []

    private let controller = SessionController()

    var session: AVCaptureSession { controller.session }

    func configureIfNeeded() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.permissionDenied = true
                    return
                }
                self.controller.configureAndStart { [weak self] detections in
                    Task { @MainActor in
                        self?.liveDetections = detections
                    }
                }
                self.isSessionReady = true
            }
        }
    }

    func stopSession() {
        controller.stop()
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        controller.startRecording { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                self.isRecording = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.lastRecordedURL = url
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        controller.stopRecording()
    }
}

/// Bukan actor-isolated sama sekali — semua pekerjaan AVFoundation berat
/// (start/stop session, rekam, deteksi live) jalan di queue miliknya sendiri,
/// bukan main thread.
private final class SessionController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.homoold.camera.session")
    private let detectionQueue = DispatchQueue(label: "com.homoold.camera.detection")
    private var recordingCompletion: (@Sendable (URL?, Error?) -> Void)?
    private var onLiveDetections: (@Sendable ([LiveDetection]) -> Void)?

    // TODO: ganti/tambah threshold per model kalau hasil training baru punya karakteristik beda.
    private let windowACDetector = LiveObjectDetector(modelName: "WindowAC")
    private let moldDampDetector = LiveObjectDetector(modelName: "MoldDamp")
    private var lastDetectionTime = Date.distantPast
    private let detectionInterval: TimeInterval = 0.35

    func configureAndStart(onLiveDetections: @escaping @Sendable ([LiveDetection]) -> Void) {
        self.onLiveDetections = onLiveDetections
        queue.async { [session, movieOutput, videoDataOutput, detectionQueue] in
            session.beginConfiguration()
            session.sessionPreset = .high

            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let cameraInput = try? AVCaptureDeviceInput(device: camera),
               session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }

            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.setSampleBufferDelegate(self, queue: detectionQueue)
                videoDataOutput.connection(with: .video)?.videoRotationAngle = 90 // portrait
            }

            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [session] in
            session.stopRunning()
        }
    }

    func startRecording(completion: @escaping @Sendable (URL?, Error?) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        queue.async { [movieOutput] in
            self.recordingCompletion = completion
            movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async { [movieOutput] in
            movieOutput.stopRecording()
        }
    }
}

extension SessionController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        recordingCompletion?(error == nil ? outputFileURL : nil, error)
        recordingCompletion = nil
    }
}

extension SessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastDetectionTime = now

        // Buffer sudah diputar tegak lewat `videoRotationAngle = 90` di connection-nya
        // (lihat configureAndStart), jadi orientasinya buat Vision sudah `.up` — bukan
        // `.right` lagi. Sebelumnya dobel-rotasi di sini bikin frame yang dikirim ke
        // model jadi miring, kemungkinan besar itu sebab AC/jendela suka gagal kedeteksi.
        var combined: [LiveDetection] = []
        if let windowACDetector {
            combined += windowACDetector.detect(in: pixelBuffer, orientation: .up)
        }
        if let moldDampDetector {
            combined += moldDampDetector.detect(in: pixelBuffer, orientation: .up)
        }
        onLiveDetections?(combined)
    }
}

/// UIViewRepresentable untuk menampilkan live preview AVCaptureSession.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}

    final class PreviewContainerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
