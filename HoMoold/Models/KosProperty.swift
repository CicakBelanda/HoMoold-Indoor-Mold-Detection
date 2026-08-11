//
//  KosProperty.swift
//  HoMoold
//

import UIKit

struct KosProperty: Identifiable {
    let id = UUID()
    var name: String
    var location: String // kecamatan
    var price: Int? // harga sewa (Rp/bulan), nil = belum diisi
    var thumbnail: UIImage
    var rooms: [RoomInspection]

    var lastInspectionDate: Date {
        rooms.map(\.date).max() ?? Date()
    }

    var highestRiskLevel: RiskLevel? {
        rooms.map(\.riskLevel).max { $0.severity < $1.severity }
    }

    var priceText: String? {
        guard let price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "Rp \(formatted) / bulan"
    }
}
