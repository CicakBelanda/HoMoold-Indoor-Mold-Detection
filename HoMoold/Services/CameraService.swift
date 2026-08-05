//
//  CameraService.swift
//  HoMoold
//
//  Wrapper AVCaptureSession untuk rekam video sungguhan di layar "Rekam Video".
//  Tidak ada mock di sini — sesi kamera & file output beneran jalan (butuh device fisik,
//  simulator tidak punya kamera).
//
//  AVCaptureSession harus dikonfigurasi/dijalankan di luar main thread, tapi
//  CameraService sendiri @MainActor (buat @Published). Supaya closure di
//  background queue tidak menyentuh state main-actor-isolated (yang bikin error
//  "Sendable closure"), semua kerja AVFoundation dipisah ke `SessionController`
//  yang bukan actor-isolated sama sekali.
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
                self.controller.configureAndStart()
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
/// (start/stop session, rekam) jalan di `queue` miliknya sendiri, bukan main thread.
private final class SessionController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.homoold.camera.session")
    private var recordingCompletion: (@Sendable (URL?, Error?) -> Void)?

    func configureAndStart() {
        queue.async { [session, movieOutput] in
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
