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
    /// Nama ruangan yang dikasih user, mis. "Bedroom A" — di Figma kartu ruangan
    /// nunjukin nama DAN tipe, jadi dua-duanya disimpan. Diisi di
    /// ConditionFormView (dulu tipe-nya dipilih di layar terpisah yang sekarang
    /// udah dihapus).
    var name: String
    let roomType: RoomType
    /// `var` karena bisa berubah kalau fotonya diedit belakangan — luas jamur
    /// ikut berubah, dan itu salah satu input RiskClassifier.
    var riskLevel: RiskLevel
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

    /// Cuaca pas inspeksi (dari WeatherService/Open-Meteo di ConditionFormView)
    /// — dipakai bareng kondisi ruangan + level keparahan buat prediksi
    /// RiskClassifier (kartu Risiko di Report). Optional karena GPS/cuaca
    /// bisa gagal diambil.
    var temperature: Float?
    var humidity: Float?
    /// Level keparahan jamur 0–3 (MoldSeverity.level) — input `Mold` model.
    var moldSeverityLevel: Int

    /// `id` di-default lewat parameter (bukan `let id = UUID()` inline) —
    /// biar `init(from decoder:)` di extension Codable di bawah bisa decode
    /// id yang beneran tersimpan, bukan ke-generate ulang tiap kali di-load.
    init(
        id: UUID = UUID(), name: String = "", roomType: RoomType, riskLevel: RiskLevel, riskScore: Int, findings: [Finding],
        capturedPhotos: [UIImage] = [], hasAC: Bool, hasWindow: Bool, dampness: Bool, wallCrack: Bool, date: Date,
        temperature: Float? = nil, humidity: Float? = nil, moldSeverityLevel: Int = 0
    ) {
        self.id = id
        // Nama kosong -> pakai nama tipe ruangan, biar kartu nggak pernah tampil
        // tanpa judul walaupun user nggak ngisi apa-apa.
        self.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? roomType.rawValue : name
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
        self.temperature = temperature
        self.humidity = humidity
        self.moldSeverityLevel = moldSeverityLevel
    }

    /// Ada jamur kedeteksi di ruangan ini. Dipakai buat milih gambar kartu:
    /// kalau nggak ada, kartunya nampilin grafis "no mold", bukan foto ruangan.
    var hasMold: Bool { !findings.isEmpty }

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
            DetectionItem(label: "Window", isPresent: hasWindow),
            DetectionItem(label: "Dampness", isPresent: dampness),
            DetectionItem(label: "Wall Crack", isPresent: wallCrack),
        ]
    }
}

/// Codable manual — sama alasannya kayak `Finding`: `capturedPhotos` itu
/// `[UIImage]`, disimpan sebagai array JPEG Data.
extension RoomInspection: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, roomType, riskLevel, riskScore, findings, capturedPhotosData, hasAC, hasWindow, dampness, wallCrack, date, temperature, humidity, moldSeverityLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        roomType = try container.decode(RoomType.self, forKey: .roomType)
        // decodeIfPresent + fallback ke nama tipe: properties.json yang udah
        // kesimpan SEBELUM field `name` ada nggak punya kunci ini, dan kalau
        // pakai decode biasa semua data lama gagal di-load.
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? roomType.rawValue
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
        temperature = try container.decodeIfPresent(Float.self, forKey: .temperature)
        humidity = try container.decodeIfPresent(Float.self, forKey: .humidity)
        moldSeverityLevel = try container.decodeIfPresent(Int.self, forKey: .moldSeverityLevel) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
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
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(humidity, forKey: .humidity)
        try container.encode(moldSeverityLevel, forKey: .moldSeverityLevel)
    }
}
