//
//  ARAreaCalculator.swift
//  HoMoold
//
//  Estimasi luas real-world (cm2) dari bounding box + depth map LiDAR.
//  Ambil median depth di dalam area box (median, bukan rata-rata, biar gak
//  kegeser sama piksel latar belakang yang ketangkep di dalam box), lalu
//  hitung lebar/tinggi asli box itu di kedalaman tsb pakai model kamera
//  pinhole standar (ukuran piksel * jarak / focal length).
//

import ARKit
import CoreVideo

enum ARAreaCalculator {
    struct Measurement {
        let areaCM2: Double
        let depthMeters: Float
        let sampledPixelCount: Int
    }

    /// - Parameters:
    ///   - box: normalized, origin kiri-atas (UIKit-style — sama kayak `LiveDetection.uiKitBoundingBox`/`Finding.boundingBox`).
    ///   - depthMap: `ARDepthData.depthMap` (disarankan `smoothedSceneDepth` kalau ada).
    ///   - confidenceMap: `ARDepthData.confidenceMap`, dipakai buat buang piksel depth yang gak reliable.
    ///   - intrinsics: `ARCamera.intrinsics`, dikalibrasi buat resolusi `imageResolution`.
    ///   - imageResolution: `ARCamera.imageResolution` (resolusi `capturedImage`).
    static func measure(
        box: CGRect,
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> Measurement? {
        guard imageResolution.width > 0, imageResolution.height > 0,
              box.width > 0, box.height > 0 else { return nil }

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

        // Box (UIKit-style, origin kiri-atas, 0...1) -> region piksel di resolusi depth map.
        let minX = max(0, Int((box.minX * CGFloat(depthWidth)).rounded(.down)))
        let maxX = min(depthWidth, Int((box.maxX * CGFloat(depthWidth)).rounded(.up)))
        let minY = max(0, Int((box.minY * CGFloat(depthHeight)).rounded(.down)))
        let maxY = min(depthHeight, Int((box.maxY * CGFloat(depthHeight)).rounded(.up)))
        guard minX < maxX, minY < maxY else { return nil }

        var depthSamples: [Float] = []
        for y in minY..<maxY {
            let depthRow = depthPtr + y * depthFloatsPerRow
            let confidenceRow = confidenceBase.map { $0 + y * confidenceBytesPerRow }
            for x in minX..<maxX {
                if let confidenceRow, confidenceRow[x] < UInt8(ARConfidenceLevel.medium.rawValue) { continue }
                let z = depthRow[x]
                guard z.isFinite, z > 0 else { continue }
                depthSamples.append(z)
            }
        }
        guard !depthSamples.isEmpty else { return nil }

        depthSamples.sort()
        let medianDepth = depthSamples[depthSamples.count / 2]

        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        guard fx > 0, fy > 0 else { return nil }

        let widthPx = Float(box.width * imageResolution.width)
        let heightPx = Float(box.height * imageResolution.height)
        let realWidthM = widthPx * medianDepth / fx
        let realHeightM = heightPx * medianDepth / fy

        return Measurement(
            areaCM2: Double(realWidthM * realHeightM) * 10_000,
            depthMeters: medianDepth,
            sampledPixelCount: depthSamples.count
        )
    }
}
