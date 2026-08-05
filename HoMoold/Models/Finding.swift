//
//  Finding.swift
//  HoMoold
//

import UIKit

struct Finding: Identifiable {
    let id = UUID()
    let boundingBox: CGRect // normalized 0-1, posisi relatif terhadap frame
    let frameImage: UIImage // frame video / foto tempat temuan ini muncul
    let findingClass: FindingClass
    let locationNote: String // contoh: "sudut plafon dekat jendela"
    var isReviewed: Bool = false
}
