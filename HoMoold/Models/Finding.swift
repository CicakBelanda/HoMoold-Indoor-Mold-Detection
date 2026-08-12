//
//  Finding.swift
//  HoMoold
//

import UIKit

struct Finding: Identifiable {
    let id = UUID()
    let boundingBox: CGRect // normalized 0-1, posisi relatif terhadap frame
    let frameImage: UIImage // foto tempat temuan ini muncul
    let findingClass: FindingClass
    let locationNote: String // contoh: "sudut plafon dekat jendela"
    /// Luas real-world (cm2) hasil pengukuran LiDAR, nil kalau depth-nya gagal
    /// dibaca pas jepret (lihat CaptureViewModel/ARAreaCalculator) atau ini
    /// temuan dummy/preview yang gak lewat pengukuran LiDAR.
    var areaCM2: Double? = nil
    var isReviewed: Bool = false
}
