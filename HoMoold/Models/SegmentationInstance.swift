//
//  SegmentationInstance.swift
//  HoMoold
//

import CoreGraphics
import Foundation

/// Satu hasil deteksi dari model segmentasi (MoldDetector.detectWithMasks),
/// lengkap dengan mask piksel — dipakai buat overlay visual + kalkulasi luas
/// via LiDAR. Beda dari `LiveDetection` (yang cuma bounding box).
struct SegmentationInstance: Identifiable {
    let id: UUID
    let label: String // "mold"
    let confidence: Float
    /// Normalized, koordinat Vision (origin kiri-bawah, y ke atas).
    let boundingBox: CGRect
    /// Mask biner row-major, ukuran `maskWidth x maskHeight` (resolusi native
    /// prototype mask model, mis. 160x160 — BUKAN resolusi gambar asli).
    /// Mencakup seluruh frame: mapping ke koordinat lain pakai rasio
    /// (mis. `x / maskWidth` buat dapetin posisi ternormalisasi 0...1, origin
    /// kiri-atas, y ke bawah), bukan asumsi piksel gambar asli.
    let mask: [Bool]
    let maskWidth: Int
    let maskHeight: Int

    init(id: UUID = UUID(), label: String, confidence: Float, boundingBox: CGRect, mask: [Bool], maskWidth: Int, maskHeight: Int) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.mask = mask
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
    }

    func maskValue(x: Int, y: Int) -> Bool {
        guard x >= 0, x < maskWidth, y >= 0, y < maskHeight else { return false }
        return mask[y * maskWidth + x]
    }

    /// Jumlah piksel true di mask — dipakai ARAreaCalculator buat validasi
    /// cepat (mask kosong = jangan coba hitung luas).
    var maskPixelCount: Int {
        mask.reduce(0) { $0 + ($1 ? 1 : 0) }
    }
}
