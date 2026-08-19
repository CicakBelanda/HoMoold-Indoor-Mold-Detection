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

    /// Sesi kameranya JALAN TERUS, ada LiDAR atau enggak.
    ///
    /// Dulu di sini `return` kalau device-nya nggak dukung sceneDepth, jadi
    /// iPhone non-Pro nggak bisa motret sama sekali. Padahal LiDAR cuma dipakai
    /// buat NGUKUR LUAS — deteksi jamurnya jalan di gambar kamera biasa lewat
    /// Vision + CoreML, dan itu nggak butuh depth apa pun. Yang hilang tanpa
    /// LiDAR cuma angka cm²-nya.
    func start() {
        isLiDARSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
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
        // Frame semantics-nya DICEK DULU sebelum dipasang. Naruh `.sceneDepth`
        // di device yang nggak dukung bikin ARKit nolak konfigurasinya, dan
        // sesinya gagal jalan — layar kamera jadi hitam, bukan cuma kehilangan
        // depth.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            // Versi yang udah difilter antar-frame (jitter-nya lebih kecil).
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
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
            case .initializing: return "Preparing camera..."
            case .excessiveMotion: return "Moving too fast, slow down a bit"
            case .insufficientFeatures: return "Insufficient light or a surface that is too plain."
            case .relocalizing: return "Adjusting position..."
            @unknown default: return "Tracking isn't stable yet"
            }
        case .notAvailable:
            return "Tracking isn't ready yet"
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
