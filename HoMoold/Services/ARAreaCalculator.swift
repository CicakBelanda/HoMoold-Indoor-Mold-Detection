//
//  ARAreaCalculator.swift
//  HoMoold
//
//  Estimasi luas real-world (cm2) pakai depth map LiDAR. Dua varian:
//  - `measure(box:...)` — dari bounding box aja, ambil median depth di
//    dalam area box lalu hitung lebar/tinggi box itu di kedalaman tsb
//    (fallback buat model task=detect yang gak punya mask).
//  - `measure(mask:...)` — dari mask segmentasi (lebih akurat, ngikutin
//    bentuk noda beneran, bukan cuma kotak): tiap piksel depth yang jatuh di
//    dalam mask dijumlah luas differential-nya sendiri-sendiri.
//  Keduanya pakai median/per-pixel Z langsung (bukan plane-fitting) — cukup
//  buat POC ini, dan otomatis ngikutin foreshortening kalau permukaannya
//  miring ke kamera.
//
//  PENTING soal koordinat: box/mask dari MoldDetector ada di ruang koordinat
//  "upright" — abis di-rotate Vision krn `orientation: .right` dipassing pas
//  device dipegang portrait (biar hasil deteksi cocok sama tampilan layar
//  yang emang portrait). Tapi `ARDepthData.depthMap` dari ARKit itu RAW,
//  gak pernah disentuh Vision, jadi masih di orientasi sensor asli
//  (landscape). Dua ruang koordinat ini BEDA — harus di-rotate biar cocok
//  sebelum query depth map pakai koordinat box/mask, kalau enggak hasil
//  sampling-nya salah total (cuma numpang nyambung kebetulan di sudut
//  tertentu, bukan beneran align) — ini penyebab awal luas yang kebaca
//  selalu kecil & konstan ga peduli target-nya beneran seluas apa.
//

import ARKit
import CoreVideo

/// `.right` (EXIF 6) artinya: data mentahnya perlu diputar 90° CW biar jadi
/// tampilan yang bener. Jadi raw -> upright = rotasi 90° CW, dan buat balik
/// dari upright -> raw (yang dibutuhin di sini buat nyocokin sama depth map)
/// perlu rotasi kebalikannya, 90° CCW.
private enum FrameRotation {
    /// Titik ternormalisasi (origin kiri-atas) dari ruang "upright" (hasil
    /// Vision, orientation .right) -> ruang "raw" (sensor asli, sama kayak
    /// capturedImage & depthMap ARKit).
    static func rawPoint(fromUpright u: CGFloat, _ v: CGFloat) -> (CGFloat, CGFloat) {
        (v, 1 - u)
    }

    /// Kebalikannya: raw -> upright.
    static func uprightPoint(fromRaw u: CGFloat, _ v: CGFloat) -> (CGFloat, CGFloat) {
        (1 - v, u)
    }

    /// CGRect versi upright (origin kiri-atas) -> CGRect versi raw. Rotasi 90°
    /// tetap ngasih rect axis-aligned, cuma width/height ketuker.
    static func rawRect(fromUpright rect: CGRect) -> CGRect {
        CGRect(x: rect.minY, y: 1 - rect.maxX, width: rect.height, height: rect.width)
    }
}

enum ARAreaCalculator {
    struct Measurement {
        let areaCM2: Double
        let depthMeters: Float
        let sampledPixelCount: Int
    }

    /// - Parameters:
    ///   - box: normalized, origin kiri-atas (UIKit-style — sama kayak `LiveDetection.uiKitBoundingBox`),
    ///     di ruang koordinat "upright" (lihat catatan orientasi di atas file ini).
    ///   - depthMap: `ARDepthData.depthMap` (disarankan `smoothedSceneDepth` kalau ada).
    ///   - confidenceMap: `ARDepthData.confidenceMap`, dipakai buat buang piksel depth yang gak reliable.
    ///   - intrinsics: `ARCamera.intrinsics`, dikalibrasi buat resolusi `imageResolution`.
    ///   - imageResolution: `ARCamera.imageResolution` (resolusi `capturedImage`, ruang koordinat "raw").
    static func measure(
        box uprightBox: CGRect,
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> Measurement? {
        guard uprightBox.width > 0, uprightBox.height > 0,
              let fx = focalLength(intrinsics, axis: 0), let fy = focalLength(intrinsics, axis: 1)
        else { return nil }

        // Rotate ke ruang "raw" dulu (sama kayak depthMap & imageResolution) —
        // lihat catatan orientasi di kepala file.
        let box = FrameRotation.rawRect(fromUpright: uprightBox)

        guard let depthSamples = sampleDepths(inRegion: box, depthMap: depthMap, confidenceMap: confidenceMap, isInside: nil),
              let medianDepth = median(depthSamples.values)
        else { return nil }

        let widthPx = Float(box.width * imageResolution.width)
        let heightPx = Float(box.height * imageResolution.height)
        let realWidthM = widthPx * medianDepth / fx
        let realHeightM = heightPx * medianDepth / fy

        return Measurement(
            areaCM2: Double(realWidthM * realHeightM) * 10_000,
            depthMeters: medianDepth,
            sampledPixelCount: depthSamples.values.count
        )
    }

    /// - Parameters:
    ///   - instance: hasil `MoldDetector.detectWithMasks` — mask-nya mencakup seluruh frame
    ///     (resolusi native prototype model, lihat `SegmentationInstance`).
    static func measure(
        mask instance: SegmentationInstance,
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> Measurement? {
        guard instance.maskWidth > 0, instance.maskHeight > 0, instance.maskPixelCount > 0,
              let fxImage = focalLength(intrinsics, axis: 0), let fyImage = focalLength(intrinsics, axis: 1)
        else { return nil }

        // intrinsics dikalibrasi buat resolusi imageResolution (capturedImage,
        // biasanya ~1920px lebar) — tapi di bawah kita jumlahin luas PER PIKSEL
        // DEPTH MAP (biasanya cuma ~256px lebar, jauh lebih rendah resolusinya).
        // Satu piksel depth map itu "mewakili" area jauh lebih gede dari satu
        // piksel capturedImage, jadi fx/fy-nya harus di-skalain ke resolusi
        // depth map dulu — kalau kepake mentah-mentah (skala imageResolution),
        // luasnya bakal ke-underestimate parah (bisa puluhan kali lebih kecil).
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard depthWidth > 0, depthHeight > 0 else { return nil }
        let fx = fxImage * Float(depthWidth) / Float(imageResolution.width)
        let fy = fyImage * Float(depthHeight) / Float(imageResolution.height)

        // Mask-nya nutupin seluruh frame (0...1 dinormalisasi), jadi region buat
        // sampling-nya ya seluruh frame — filter beneran ada di `isInside`.
        // `sampleDepths` ngasih koordinat ke closure ini dalam ruang "raw" (sama
        // kayak depthMap-nya), sedangkan mask ada di ruang "upright" — rotate
        // dulu sebelum query mask (lihat catatan orientasi di kepala file).
        let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
        let isInside: (CGFloat, CGFloat) -> Bool = { rawX, rawY in
            let (maskU, maskV) = FrameRotation.uprightPoint(fromRaw: rawX, rawY)
            return instance.maskValue(x: Int(maskU * CGFloat(instance.maskWidth)), y: Int(maskV * CGFloat(instance.maskHeight)))
        }

        guard let samples = sampleDepths(inRegion: fullFrame, depthMap: depthMap, confidenceMap: confidenceMap, isInside: isInside),
              !samples.values.isEmpty
        else { return nil }

        // Per-pixel differential area: tiap piksel depth punya Z sendiri, jadi
        // sudut pandang miring otomatis ikut terhitung (piksel yang lebih jauh
        // "mewakili" area fisik yang lebih besar).
        var totalAreaM2: Double = 0
        for z in samples.values {
            totalAreaM2 += Double(z / fx) * Double(z / fy)
        }

        return Measurement(
            areaCM2: totalAreaM2 * 10_000,
            depthMeters: median(samples.values) ?? samples.values[0],
            sampledPixelCount: samples.values.count
        )
    }

    // MARK: - Shared depth sampling

    private static func focalLength(_ intrinsics: simd_float3x3, axis: Int) -> Float? {
        let value = intrinsics[axis][axis]
        return value > 0 ? value : nil
    }

    private static func median(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// Kumpulin nilai depth (dalam meter) di dalam `region` (normalized, origin
    /// kiri-atas, 0...1) dari `depthMap`, buang piksel confidence rendah, dan
    /// filter tambahan lewat `isInside(normalizedX, normalizedY)` kalau ada
    /// (dipakai buat masking — nil berarti seluruh region dipakai).
    private static func sampleDepths(
        inRegion region: CGRect,
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        isInside: ((CGFloat, CGFloat) -> Bool)?
    ) -> (values: [Float], count: Int)? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthFloatsPerRow = depthBytesPerRow / MemoryLayout<Float32>.stride
        let depthPtr = depthBase.assumingMemoryBound(to: Float32.self)

        var confidenceBase: UnsafeMutablePointer<UInt8>?
        var confidenceBytesPerRow = 0
        if let confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confidenceBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
            if let base = CVPixelBufferGetBaseAddress(confidenceMap) {
                confidenceBase = base.assumingMemoryBound(to: UInt8.self)
            }
        }
        defer {
            if confidenceMap != nil { CVPixelBufferUnlockBaseAddress(confidenceMap!, .readOnly) }
        }

        let minX = max(0, Int((region.minX * CGFloat(depthWidth)).rounded(.down)))
        let maxX = min(depthWidth, Int((region.maxX * CGFloat(depthWidth)).rounded(.up)))
        let minY = max(0, Int((region.minY * CGFloat(depthHeight)).rounded(.down)))
        let maxY = min(depthHeight, Int((region.maxY * CGFloat(depthHeight)).rounded(.up)))
        guard minX < maxX, minY < maxY else { return nil }

        var values: [Float] = []
        for y in minY..<maxY {
            let depthRow = depthPtr + y * depthFloatsPerRow
            let confidenceRow = confidenceBase.map { $0 + y * confidenceBytesPerRow }
            let normY = (CGFloat(y) + 0.5) / CGFloat(depthHeight)
            for x in minX..<maxX {
                if let confidenceRow, confidenceRow[x] < UInt8(ARConfidenceLevel.medium.rawValue) { continue }
                if let isInside {
                    let normX = (CGFloat(x) + 0.5) / CGFloat(depthWidth)
                    guard isInside(normX, normY) else { continue }
                }
                let z = depthRow[x]
                guard z.isFinite, z > 0 else { continue }
                values.append(z)
            }
        }
        guard !values.isEmpty else { return nil }
        return (values, values.count)
    }
}
