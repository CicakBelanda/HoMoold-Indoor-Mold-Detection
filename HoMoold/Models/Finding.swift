//
//  Finding.swift
//  HoMoold
//

import UIKit

struct Finding: Identifiable {
    let id: UUID
    let boundingBox: CGRect // normalized 0-1, posisi relatif terhadap frame
    let frameImage: UIImage // foto tempat temuan ini muncul
    let findingClass: FindingClass
    let locationNote: String // contoh: "sudut plafon dekat jendela"
    /// Luas real-world (cm2) hasil pengukuran LiDAR, nil kalau depth-nya gagal
    /// dibaca pas jepret (lihat CaptureViewModel/ARAreaCalculator) atau ini
    /// temuan dummy/preview yang gak lewat pengukuran LiDAR.
    var areaCM2: Double? = nil
    var isReviewed: Bool = false

    /// `id` di-default lewat parameter (bukan `let id = UUID()` inline) —
    /// biar `init(from decoder:)` di extension Codable di bawah bisa decode
    /// id yang beneran tersimpan, bukan ke-generate ulang tiap kali di-load.
    init(
        id: UUID = UUID(), boundingBox: CGRect, frameImage: UIImage, findingClass: FindingClass,
        locationNote: String, areaCM2: Double? = nil, isReviewed: Bool = false
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.frameImage = frameImage
        self.findingClass = findingClass
        self.locationNote = locationNote
        self.areaCM2 = areaCM2
        self.isReviewed = isReviewed
    }
}

/// Codable manual (bukan sintesis compiler) — satu-satunya alasan: `frameImage`
/// itu UIImage, disimpan sebagai JPEG Data.
extension Finding: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, boundingBox, frameImageData, findingClass, locationNote, areaCM2, isReviewed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        boundingBox = try container.decode(CGRect.self, forKey: .boundingBox)
        let data = try container.decode(Data.self, forKey: .frameImageData)
        frameImage = UIImage(data: data) ?? UIImage()
        findingClass = try container.decode(FindingClass.self, forKey: .findingClass)
        locationNote = try container.decode(String.self, forKey: .locationNote)
        areaCM2 = try container.decodeIfPresent(Double.self, forKey: .areaCM2)
        isReviewed = try container.decode(Bool.self, forKey: .isReviewed)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(boundingBox, forKey: .boundingBox)
        try container.encode(frameImage.jpegData(compressionQuality: 0.7) ?? Data(), forKey: .frameImageData)
        try container.encode(findingClass, forKey: .findingClass)
        try container.encode(locationNote, forKey: .locationNote)
        try container.encodeIfPresent(areaCM2, forKey: .areaCM2)
        try container.encode(isReviewed, forKey: .isReviewed)
    }
}
