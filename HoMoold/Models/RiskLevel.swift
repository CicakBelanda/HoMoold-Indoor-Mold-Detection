//
//  RiskLevel.swift
//  HoMoold
//

import SwiftUI

enum RiskLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    static func level(forScore score: Int) -> RiskLevel {
        switch score {
        case ..<40: return .low
        case 40..<70: return .medium
        default: return .high
        }
    }

    var labelID: String {
        switch self {
        case .low: return "Rendah"
        case .medium: return "Sedang"
        case .high: return "Tinggi"
        }
    }
}
