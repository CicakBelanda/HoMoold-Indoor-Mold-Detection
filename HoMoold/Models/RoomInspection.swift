//
//  RoomInspection.swift
//  HoMoold
//

import UIKit

struct DetectionItem: Identifiable {
    let id = UUID()
    let label: String
    let isPresent: Bool
}

struct RoomInspection: Identifiable {
    let id = UUID()
    let roomType: RoomType
    let riskLevel: RiskLevel
    let riskScore: Int // 0-100
    var findings: [Finding]
    /// Foto yang diambil tapi 0 jamur kedeteksi di dalamnya — tetap disimpan
    /// (bukan dibuang) supaya Report nunjukin foto asli yang barusan diambil,
    /// bukan ilustrasi placeholder, lihat CaptureViewModel.acceptCurrentCapture.
    var capturedPhotos: [UIImage] = []
    /// Kondisi ruangan — diisi manual sama user di form Condition (bukan AI),
    /// lihat ConditionFormView. `var` karena bisa diubah belakangan lewat
    /// EditRoomConditionSheet di halaman detail rumah.
    var hasAC: Bool
    var hasWindow: Bool
    var dampness: Bool
    var wallCrack: Bool
    let date: Date

    var thumbnail: UIImage {
        findings.first?.frameImage ?? capturedPhotos.first ?? PlaceholderImageFactory.roomImage(for: roomType, seed: id.hashValue)
    }

    /// Total luas jamur yang kedeteksi (cm2) — nil kalau gak ada satu pun
    /// temuan yang berhasil diukur luasnya.
    var totalAreaCM2: Double? {
        let measured = findings.compactMap(\.areaCM2)
        guard !measured.isEmpty else { return nil }
        return measured.reduce(0, +)
    }

    /// Ringkasan cepat kondisi ruangan (Bagian 5.6 — versi checklist), diisi
    /// manual lewat ConditionFormView, bukan hasil deteksi AI.
    var detectionChecklist: [DetectionItem] {
        [
            DetectionItem(label: "AC", isPresent: hasAC),
            DetectionItem(label: "Jendela", isPresent: hasWindow),
            DetectionItem(label: "Lembap", isPresent: dampness),
            DetectionItem(label: "Retak Dinding", isPresent: wallCrack),
        ]
    }
}
