//
//  MoldMeasureViewModel.swift
//  HoMoold
//
//  Layar test terpisah — BUKAN bagian dari flow inspeksi asli. Tujuannya cuma
//  buat ngetes: bisa gak model + depth LiDAR ngasih angka luas jamur yang
//  masuk akal. Tiap ~0.4 detik: ambil ARFrame terbaru, jalanin deteksi
//  (dengan mask kalau model-nya segmentasi — lihat MoldDetector) + kalkulasi
//  luas dari depth di dalam mask/box, publish hasilnya buat MoldMeasureView
//  gambar overlay + angka live.
//
//  Posisi box di-smoothing (lerp ke posisi baru, bukan lompat langsung) dan
//  ada grace period sebelum box dihapus kalau sempat kelewat sekali/dua kali
//  — ini yang bikin box gak lagi "berganti-ganti"/flicker tiap tick. Mask-nya
//  sendiri gak di-smoothing (cukup stabil secara visual di throttle 0.4s).
//

import ARKit
import Combine
import Foundation

struct TrackedDetection: Identifiable {
    let id: UUID
    var findingClass: FindingClass
    var box: CGRect // UIKit-style normalized (origin kiri-atas), sudah di-smoothing
    var mask: SegmentationInstance? // ada kalau model-nya segmentasi & mask-nya gak kosong
    var areaText: String?
    var rangeWarning: String?
    var missedTicks: Int
}

@MainActor
final class MoldMeasureViewModel: ObservableObject {
    @Published private(set) var instances: [TrackedDetection] = []
    @Published var isFrozen = false
    @Published private(set) var isWaitingForDepth = false
    @Published private(set) var modelUnavailable = false
    /// Ringkasan tick terakhir dari MoldDetector, ditampilin langsung di layar
    /// (bukan cuma console) biar bisa didiagnosa dari HP tanpa Xcode.
    @Published private(set) var debugText = ""

    let arSession = ARDepthCaptureSession()

    // Threshold sengaja diturunin jauh (harusnya 0.35) — ini murni buat
    // diagnosa: kalau di sini aja masih gak ada yang muncul, berarti masalahnya
    // bukan soal confidence/threshold, ada yang lebih dasar gak jalan. Naikin
    // lagi begitu udah kelihatan overlay muncul.
    private let detector = MoldDetector(modelName: "MoldDampSeg", confidenceThreshold: 0.02)
    private var timer: Timer?
    private var isProcessing = false
    private let tickInterval: TimeInterval = 0.4

    // Jarak efektif sceneDepth LiDAR di iPhone kira-kira segini — di luar
    // rentang ini datanya makin gak akurat/noisy, jadi luasnya gak ditampilin.
    private static let minRangeMeters: Float = 0.2
    private static let maxRangeMeters: Float = 5.0

    // Smoothing/hysteresis biar box gak flicker tiap tick.
    private static let smoothingFactor: CGFloat = 0.35
    private static let matchDistanceThreshold: CGFloat = 0.25
    private static let maxMissedTicks = 2

    func start() {
        modelUnavailable = detector == nil
        arSession.start()
        guard arSession.isLiDARSupported else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        arSession.stop()
    }

    func toggleFreeze() {
        isFrozen.toggle()
    }

    private struct FreshDetection {
        let findingClass: FindingClass
        let box: CGRect
        let mask: SegmentationInstance?
        let areaText: String?
        let rangeWarning: String?
    }

    private func tick() {
        guard !isFrozen, !isProcessing, let detector, let frame = arSession.currentFrame() else { return }
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            isWaitingForDepth = true
            return
        }
        isWaitingForDepth = false
        isProcessing = true

        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        let imageResolution = frame.camera.imageResolution

        Task.detached(priority: .userInitiated) { [weak self] in
            // Device dipegang portrait, tapi capturedImage itu buffer sensor mentah
            // (landscape) — orientation .right biar Vision balikin koordinat yang
            // udah tegak, sama seperti konvensi ARKit+Vision pada umumnya.
            let raw = detector.detectWithMasks(in: pixelBuffer, orientation: .right)
            let diagnostics = detector.lastDiagnostics

            var results: [FreshDetection] = []
            for instance in raw {
                guard let findingClass = FindingClass(rawValue: instance.label.uppercased()) else { continue }
                let box = CGRect(
                    x: instance.boundingBox.minX,
                    y: 1 - instance.boundingBox.maxY,
                    width: instance.boundingBox.width,
                    height: instance.boundingBox.height
                )
                let hasMask = instance.maskPixelCount > 0

                let measurement = hasMask
                    ? ARAreaCalculator.measure(
                        mask: instance, depthMap: depthData.depthMap, confidenceMap: depthData.confidenceMap,
                        intrinsics: intrinsics, imageResolution: imageResolution
                    )
                    : ARAreaCalculator.measure(
                        box: box, depthMap: depthData.depthMap, confidenceMap: depthData.confidenceMap,
                        intrinsics: intrinsics, imageResolution: imageResolution
                    )

                var areaText: String?
                var rangeWarning: String?
                if let measurement {
                    if measurement.depthMeters < Self.minRangeMeters {
                        rangeWarning = "Terlalu dekat — jauhkan kamera dikit"
                    } else if measurement.depthMeters > Self.maxRangeMeters {
                        rangeWarning = "Terlalu jauh buat LiDAR (maks ~\(Int(Self.maxRangeMeters))m) — dekatkan kamera"
                    } else {
                        areaText = String(format: "%.0f cm²", measurement.areaCM2)
                    }
                }

                results.append(FreshDetection(
                    findingClass: findingClass, box: box, mask: hasMask ? instance : nil,
                    areaText: areaText, rangeWarning: rangeWarning
                ))
            }

            await MainActor.run {
                guard let self else { return }
                self.applySmoothing(results)
                self.debugText = diagnostics
                self.isProcessing = false
            }
        }
    }

    /// Matching sederhana berdasar kelas + jarak center ke deteksi tick sebelumnya.
    /// Posisi box yang ke-match di-lerp ke posisi baru (bukan lompat langsung);
    /// yang gak ke-match dikasih grace period beberapa tick sebelum bener-bener
    /// dihapus.
    private func applySmoothing(_ fresh: [FreshDetection]) {
        var matchedIndices = Set<Int>()
        var updated: [TrackedDetection] = []

        for var existing in instances {
            var bestIndex: Int?
            var bestDistance = Self.matchDistanceThreshold
            for (index, detection) in fresh.enumerated()
            where !matchedIndices.contains(index) && detection.findingClass == existing.findingClass {
                let distance = centerDistance(existing.box, detection.box)
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = index
                }
            }

            if let bestIndex {
                matchedIndices.insert(bestIndex)
                let match = fresh[bestIndex]
                existing.box = lerp(existing.box, match.box, Self.smoothingFactor)
                existing.mask = match.mask
                existing.areaText = match.areaText
                existing.rangeWarning = match.rangeWarning
                existing.missedTicks = 0
                updated.append(existing)
            } else {
                existing.missedTicks += 1
                if existing.missedTicks <= Self.maxMissedTicks {
                    updated.append(existing)
                }
            }
        }

        for (index, detection) in fresh.enumerated() where !matchedIndices.contains(index) {
            updated.append(TrackedDetection(
                id: UUID(),
                findingClass: detection.findingClass,
                box: detection.box,
                mask: detection.mask,
                areaText: detection.areaText,
                rangeWarning: detection.rangeWarning,
                missedTicks: 0
            ))
        }

        instances = updated
    }

    private func centerDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return (dx * dx + dy * dy).squareRoot()
    }

    private func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * t,
            y: a.minY + (b.minY - a.minY) * t,
            width: a.width + (b.width - a.width) * t,
            height: a.height + (b.height - a.height) * t
        )
    }
}
