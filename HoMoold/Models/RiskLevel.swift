//
//  RiskLevel.swift
//  HoMoold
//

import SwiftUI

enum RiskLevel: String, Codable, CaseIterable {
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

    /// Skor risiko default di tengah rentang levelnya, dipakai kalau butuh angka tanpa hitungan penuh.
    var scoreRange: ClosedRange<Int> {
        switch self {
        case .low: return 0...39
        case .medium: return 40...69
        case .high: return 70...100
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

    var severity: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}
