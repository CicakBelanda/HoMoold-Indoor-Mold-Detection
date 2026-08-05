//
//  KosProperty.swift
//  HoMoold
//

import UIKit

struct KosProperty: Identifiable {
    let id = UUID()
    var name: String
    var location: String // kecamatan
    var thumbnail: UIImage
    var rooms: [RoomInspection]

    var lastInspectionDate: Date {
        rooms.map(\.date).max() ?? Date()
    }

    var highestRiskLevel: RiskLevel? {
        rooms.map(\.riskLevel).max { $0.severity < $1.severity }
    }
}
