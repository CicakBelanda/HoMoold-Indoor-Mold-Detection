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
    let id: UUID
    let roomType: RoomType
    let riskLevel: RiskLevel
    let riskScore: Int // 0-100
    var findings: [Finding]
    /// Foto yang diambil tapi 0 jamur kedeteksi di dalamnya — tetap disimpan
    /// (bukan dibuang) supaya Report nunjukin foto asli yang barusan diambil,
    /// bukan ilustrasi placeholder, lihat CaptureViewModel.acceptCurrentCapture.
    var capturedPhotos: [UIImage]
    /// Kondisi ruangan — diisi manual sama user di form Condition (bukan AI),
    /// lihat ConditionFormView. `var` karena bisa diubah belakangan lewat
    /// EditRoomConditionSheet di halaman detail rumah.
    var hasAC: Bool
    var hasWindow: Bool
    var dampness: Bool
    var wallCrack: Bool
    let date: Date

    /// `id` di-default lewat parameter (bukan `let id = UUID()` inline) —
    /// biar `init(from decoder:)` di extension Codable di bawah bisa decode
    /// id yang beneran tersimpan, bukan ke-generate ulang tiap kali di-load.
    init(
        id: UUID = UUID(), roomType: RoomType, riskLevel: RiskLevel, riskScore: Int, findings: [Finding],
        capturedPhotos: [UIImage] = [], hasAC: Bool, hasWindow: Bool, dampness: Bool, wallCrack: Bool, date: Date
    ) {
        self.id = id
        self.roomType = roomType
        self.riskLevel = riskLevel
        self.riskScore = riskScore
        self.findings = findings
        self.capturedPhotos = capturedPhotos
        self.hasAC = hasAC
        self.hasWindow = hasWindow
        self.dampness = dampness
        self.wallCrack = wallCrack
        self.date = date
    }

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

/// Codable manual — sama alasannya kayak `Finding`: `capturedPhotos` itu
/// `[UIImage]`, disimpan sebagai array JPEG Data.
extension RoomInspection: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, roomType, riskLevel, riskScore, findings, capturedPhotosData, hasAC, hasWindow, dampness, wallCrack, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        roomType = try container.decode(RoomType.self, forKey: .roomType)
        riskLevel = try container.decode(RiskLevel.self, forKey: .riskLevel)
        riskScore = try container.decode(Int.self, forKey: .riskScore)
        findings = try container.decode([Finding].self, forKey: .findings)
        let photosData = try container.decodeIfPresent([Data].self, forKey: .capturedPhotosData) ?? []
        capturedPhotos = photosData.compactMap { UIImage(data: $0) }
        hasAC = try container.decode(Bool.self, forKey: .hasAC)
        hasWindow = try container.decode(Bool.self, forKey: .hasWindow)
        dampness = try container.decode(Bool.self, forKey: .dampness)
        wallCrack = try container.decode(Bool.self, forKey: .wallCrack)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roomType, forKey: .roomType)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(riskScore, forKey: .riskScore)
        try container.encode(findings, forKey: .findings)
        try container.encode(capturedPhotos.compactMap { $0.jpegData(compressionQuality: 0.7) }, forKey: .capturedPhotosData)
        try container.encode(hasAC, forKey: .hasAC)
        try container.encode(hasWindow, forKey: .hasWindow)
        try container.encode(dampness, forKey: .dampness)
        try container.encode(wallCrack, forKey: .wallCrack)
        try container.encode(date, forKey: .date)
    }
}
