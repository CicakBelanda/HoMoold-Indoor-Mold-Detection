//
//  Finding.swift
//  HoMoold
//

import UIKit

struct Finding: Identifiable {
    let id: UUID
    /// ID jepretan asalnya. Semua temuan dari SATU foto punya nilai yang sama.
    ///
    /// Perlu karena satu foto bisa berisi beberapa titik jamur, dan tanpa ini
    /// Report nampilin foto yang sama berkali-kali (satu per temuan). Nggak bisa
    /// ngandelin `frameImage` sebagai kunci: UIImage nggak Hashable per isi, dan
    /// setelah di-decode dari disk tiap Finding dapat instance UIImage sendiri.
    let captureID: UUID
    let boundingBox: CGRect // normalized 0-1, posisi relatif terhadap frame
    let frameImage: UIImage // foto tempat temuan ini muncul
    let findingClass: FindingClass
    let locationNote: String // contoh: "sudut plafon dekat jendela"
    /// Luas real-world (cm2) hasil pengukuran LiDAR, nil kalau depth-nya gagal
    /// dibaca pas jepret (lihat CaptureViewModel/ARAreaCalculator) atau ini
    /// temuan dummy/preview yang gak lewat pengukuran LiDAR.
    var areaCM2: Double? = nil
    let confidence: Double
    var isReviewed: Bool = false
    /// `true` kalau temuan ini dari tandai manual (bukan deteksi ML otomatis).
    /// Dipakai buat nanda di preview/report kalau user sendiri yang nentuin
    /// luasnya — dan biar kita gak ngaku ini hasil model.
    var isManual: Bool = false

    /// `id` di-default lewat parameter (bukan `let id = UUID()` inline) —
    /// biar `init(from decoder:)` di extension Codable di bawah bisa decode
    /// id yang beneran tersimpan, bukan ke-generate ulang tiap kali di-load.
    init(
        id: UUID = UUID(), captureID: UUID = UUID(), boundingBox: CGRect, frameImage: UIImage,
        findingClass: FindingClass, locationNote: String, areaCM2: Double? = nil, confidence:Double, isReviewed: Bool = false,
        isManual: Bool = false
    ) {
        self.id = id
        self.captureID = captureID
        self.boundingBox = boundingBox
        self.frameImage = frameImage
        self.findingClass = findingClass
        self.locationNote = locationNote
        self.areaCM2 = areaCM2
        self.confidence = confidence
        self.isReviewed = isReviewed
        self.isManual = isManual
    }
}

/// Codable manual (bukan sintesis compiler) — satu-satunya alasan: `frameImage`
/// itu UIImage, disimpan sebagai JPEG Data.
extension Finding: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, captureID, boundingBox, frameImageData, findingClass, locationNote, areaCM2, confidence, isReviewed, isManual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        // Data lama nggak punya captureID. Fallback ke `id` sendiri berarti tiap
        // temuan lama dianggap dari jepretan sendiri-sendiri — persis perilaku
        // sebelumnya, jadi nggak ada yang berubah buat data yang udah ada.
        captureID = try container.decodeIfPresent(UUID.self, forKey: .captureID) ?? id
        boundingBox = try container.decode(CGRect.self, forKey: .boundingBox)
        let data = try container.decode(Data.self, forKey: .frameImageData)
        frameImage = UIImage(data: data) ?? UIImage()
        findingClass = try container.decode(FindingClass.self, forKey: .findingClass)
        locationNote = try container.decode(String.self, forKey: .locationNote)
        areaCM2 = try container.decodeIfPresent(Double.self, forKey: .areaCM2)
        confidence = try container.decode(Double.self, forKey: .confidence)
        isReviewed = try container.decode(Bool.self, forKey: .isReviewed)
        // `isManual` cuma ada sejak fitur tandai manual — data lama gak punya
        // kuncinya, jadi `decodeIfPresent` + default false biar tetap ke-load.
        isManual = try container.decodeIfPresent(Bool.self, forKey: .isManual) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(captureID, forKey: .captureID)
        try container.encode(boundingBox, forKey: .boundingBox)
        try container.encode(frameImage.jpegData(compressionQuality: 0.7) ?? Data(), forKey: .frameImageData)
        try container.encode(findingClass, forKey: .findingClass)
        try container.encode(locationNote, forKey: .locationNote)
        try container.encodeIfPresent(areaCM2, forKey: .areaCM2)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(isReviewed, forKey: .isReviewed)
        try container.encode(isManual, forKey: .isManual)
    }
}
