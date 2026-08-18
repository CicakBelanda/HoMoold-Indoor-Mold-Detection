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
        controller.onTrackingMessage = { message in
            Task { @MainActor in self.trackingMessage = message }
        }
        controller.start()
    }

    func stop() {
        controller.stop()
    }

    /// Jalanin ulang sesi dengan/tanpa rekonstruksi mesh. Mode tandai manual
    /// butuh mesh aktif biar raycast dari layar nabrak permukaan nyata (bukan
    /// bidang datar perkiraan) — lihat catatan di CaptureViewModel.buildManualFinding.
    /// Di luar mode itu mesh dimatiin biar sesi lebih ringan (cuma butuh sceneDepth).
    func applyManualMode(_ enabled: Bool) {
        controller.applyManualMode(enabled)
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

    /// Jalanin ulang dengan mesh nyala/mati tergantung `enabled`. Dipanggil
    /// pas mode kamera berubah (Auto <-> Manual) tanpa bikin ARSession baru.
    func applyManualMode(_ enabled: Bool) {
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics.insert(.sceneDepth)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        // Mesh cuma dibutuhin (dan cuma didukung) di mode Manual.
        if enabled, ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        // `run` dengan config beda = restart sesi. `isRelocalizing` biar
        // tracking-nya nggak mulai dari nol, tapi mesh-nya dibangun ulang.
        session.run(config, options: [.removeExistingAnchors, .resetSceneReconstruction])
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
///
/// Di mode Manual (tandai sendiri), view ini yang pegang gestur tap/long-press
/// dan raycast ke permukaan nyata (mesh LiDAR, lihat ARDepthCaptureSession
/// `.applyManualMode`) — koordinat dunia-nya dikembalikan lewat `onCornersChanged`
/// biar `CaptureViewModel` yang hitung luasnya. Marker kuning + garis polygon
/// digambar langsung di scene 3D biar nempel ke bidang aslinya (bukan cuma di
/// layar), jadi tetap pas walau kamera digerakkan.
struct ARPassthroughView: UIViewRepresentable {
    let session: ARSession
    /// `true` di mode Manual — nyalain gestur tandai & raycast.
    var manualMode: Bool = false
    /// Dipanggil tiap titik bertambah/berkurang (array lengkap titik dunia, meter).
    var onCornersChanged: (([SIMD3<Float>]) -> Void)?
    /// Inkremen nilainya buat suruh Coordinator bersihin marker (pas simpan area).
    @Binding var resetToken: Int

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let reset = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleReset(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(reset)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.parent = self
        // `resetToken` naik -> user baru aja simpan area, bersihkan marker 3D.
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.clearMarkers(in: uiView)
            context.coordinator.lastResetToken = resetToken
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Coordinator tandai manual

    final class Coordinator: NSObject {
        var parent: ARPassthroughView
        var worldPoints: [SIMD3<Float>] = []
        var sceneNodes: [SCNNode] = []
        var lastResetToken: Int

        init(_ parent: ARPassthroughView) {
            self.parent = parent
            self.lastResetToken = parent.resetToken
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Gestur selalu ada, tapi cuma berlaku di mode Manual — di mode Auto
            // layar kamera tetap bebas buat diklik tanpa nandain apa-apa.
            guard parent.manualMode,
                  let arView = gesture.view as? ARSCNView else { return }
            let location = gesture.location(in: arView)

            // Raycast dari titik layar ke permukaan nyata (mesh LiDAR). Ini
            // ngelicin seluruh urusan "screen point -> depth map -> intrinsics
            // -> unproject": ARKit yang urus transformasi kamera-ke-dunia, jadi
            // titik yang didapat udah koordinat dunia nyata (meter).
            guard let query = arView.raycastQuery(
                from: location, allowing: .estimatedPlane, alignment: .any
            ) else { return }

            guard let result = arView.session.raycast(query).first else {
                parent.onCornersChanged?(worldPoints)
                return
            }

            let worldPos = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            worldPoints.append(worldPos)
            addMarker(at: worldPos, in: arView)
            parent.onCornersChanged?(worldPoints)
        }

        @objc func handleReset(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  parent.manualMode,
                  let arView = gesture.view as? ARSCNView else { return }
            clearMarkers(in: arView)
            parent.onCornersChanged?(worldPoints)
        }

        func clearMarkers(in arView: ARSCNView) {
            worldPoints.removeAll()
            sceneNodes.forEach { $0.removeFromParentNode() }
            sceneNodes.removeAll()
        }

        // MARK: Visual marker + garis penghubung

        private func addMarker(at position: SIMD3<Float>, in arView: ARSCNView) {
            let sphere = SCNSphere(radius: 0.006)
            sphere.firstMaterial?.diffuse.contents = UIColor.systemYellow
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(position.x, position.y, position.z)
            arView.scene.rootNode.addChildNode(node)
            sceneNodes.append(node)

            if worldPoints.count > 1 {
                let prev = worldPoints[worldPoints.count - 2]
                let lineNode = makeLine(from: prev, to: position)
                arView.scene.rootNode.addChildNode(lineNode)
                sceneNodes.append(lineNode)
            }
            // >= 3 titik: tutup polygon dengan garis dari titik terakhir ke
            // titik pertama biar area keliatan jelas.
            if worldPoints.count >= 3 {
                let first = worldPoints[0]
                let closing = makeLine(from: position, to: first)
                closing.name = "closingLine"
                sceneNodes.filter { $0.name == "closingLine" }.forEach { $0.removeFromParentNode() }
                arView.scene.rootNode.addChildNode(closing)
                sceneNodes.append(closing)
            }
        }

        private func makeLine(from a: SIMD3<Float>, to b: SIMD3<Float>) -> SCNNode {
            let source = SCNGeometrySource(vertices: [SCNVector3(a.x, a.y, a.z), SCNVector3(b.x, b.y, b.z)])
            let indices: [Int32] = [0, 1]
            let element = SCNGeometryElement(indices: indices, primitiveType: .line)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial?.diffuse.contents = UIColor.systemYellow
            return SCNNode(geometry: geometry)
        }
    }
}
