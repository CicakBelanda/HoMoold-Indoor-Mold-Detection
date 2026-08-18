//
//  LiveDetection.swift
//  HoMoold
//

import CoreGraphics
import Foundation

/// Satu hasil deteksi real-time dari kamera (bukan hasil final Report).
struct LiveDetection: Identifiable {
    let id = UUID()
    let label: String // selalu "mold" — lihat MoldDetector, channel "damp" di-skip
    let confidence: Float
    /// Normalized, koordinat Vision (origin kiri-bawah, y ke atas).
    let boundingBox: CGRect

    /// Dikonversi ke koordinat UIKit/SwiftUI (origin kiri-atas, y ke bawah) buat overlay.
    var uiKitBoundingBox: CGRect {
        CGRect(x: boundingBox.minX, y: 1 - boundingBox.maxY, width: boundingBox.width, height: boundingBox.height)
    }
}
