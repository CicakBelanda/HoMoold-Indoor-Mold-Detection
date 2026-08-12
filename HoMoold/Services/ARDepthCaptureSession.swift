//
//  ARDepthCaptureSession.swift
//  HoMoold
//
//  Wrapper ARSession buat layar ambil foto jamur pas inspeksi (lihat
//  Features/Inspection/CaptureView.swift). Cuma butuh passthrough kamera +
//  sceneDepth LiDAR, bukan anchor/konten 3D apa pun.
//
//  ARSession delegate dipanggil di queue milik ARKit sendiri, bukan main
//  thread, jadi kerjanya dipisah ke `ARController` yang bukan actor-isolated
//  sama sekali.
//

import ARKit
import Combine
import SwiftUI

@MainActor
final class ARDepthCaptureSession: ObservableObject {
    @Published var isLiDARSupported = true
    @Published var trackingMessage: String?

    private let controller = ARController()

    var session: ARSession { controller.session }

    func start() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            isLiDARSupported = false
            return
        }
        controller.onTrackingMessage = { [weak self] message in
            Task { @MainActor in self?.trackingMessage = message }
        }
        controller.start()
    }

    func stop() {
        controller.stop()
    }

    /// Frame ARKit paling baru — dipanggil dari loop throttled `MoldMeasureViewModel`
    /// buat ambil capturedImage + depth sekaligus, bukan lewat delegate per-frame.
    func currentFrame() -> ARFrame? {
        controller.session.currentFrame
    }
}

private final class ARController: NSObject, @unchecked Sendable {
    let session = ARSession()
    var onTrackingMessage: (@Sendable (String?) -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics.insert(.sceneDepth)
        // smoothedSceneDepth (temporally filtered, kurang jitter) dipakai kalau
        // device-nya dukung — MoldMeasureViewModel fallback ke sceneDepth kalau nil.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        session.run(config)
    }

    func stop() {
        session.pause()
    }
}

extension ARController: ARSessionDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        onTrackingMessage?(Self.message(for: camera.trackingState))
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onTrackingMessage?(error.localizedDescription)
    }

    private static func message(for state: ARCamera.TrackingState) -> String? {
        switch state {
        case .normal:
            return nil
        case .limited(let reason):
            switch reason {
            case .initializing: return "Menyiapkan kamera..."
            case .excessiveMotion: return "Gerakan terlalu cepat, pelanin dikit"
            case .insufficientFeatures: return "Cahaya kurang atau permukaan terlalu polos"
            case .relocalizing: return "Menyesuaikan posisi..."
            @unknown default: return "Tracking belum stabil"
            }
        case .notAvailable:
            return "Tracking belum siap"
        }
    }
}

/// UIViewRepresentable pure-passthrough — nampilin feed kamera ARKit tanpa
/// anchor/konten 3D apa pun.
struct ARPassthroughView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = false
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
