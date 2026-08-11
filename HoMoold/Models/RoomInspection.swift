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
    let videoURL: URL?
    let date: Date

    var thumbnail: UIImage {
        findings.first?.frameImage ?? PlaceholderImageFactory.roomImage(for: roomType, seed: id.hashValue)
    }

    var summaryText: String {
        let count = findings.count
        let locations = findings.map(\.locationNote).prefix(2).joined(separator: " dan ")
        if count == 0 {
            return "Belum ada tanda pra-jamur yang terdeteksi jelas di ruangan ini."
        }
        return "Di ruangan ini terdeteksi \(count) titik tanda pra-jamur di lokasi berbeda, termasuk di \(locations)."
    }

    /// Ringkasan cepat: apa saja yang kedeteksi di ruangan ini (Bagian 5.6 — versi checklist).
    var detectionChecklist: [DetectionItem] {
        [
            DetectionItem(label: "Jamur", isPresent: findings.contains { $0.findingClass == .mold }),
            DetectionItem(label: "Retak", isPresent: findings.contains { $0.findingClass == .crack }),
        ]
    }
}
