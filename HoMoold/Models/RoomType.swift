//
//  RoomType.swift
//  HoMoold
//

import Foundation

enum RoomType: String, CaseIterable, Identifiable {
    case bedroom = "Bedroom"
    case bathroom = "Bathroom"
    case kitchen = "Kitchen"
    case livingRoom = "Living Room"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .bedroom: return "bed.double.fill"
        case .bathroom: return "shower.fill"
        case .kitchen: return "fork.knife"
        case .livingRoom: return "sofa.fill"
        }
    }

    /// Versi outline (bukan filled) — dipakai di chip jumlah kamar per tipe
    /// di kartu rumah (Home/Home Detail), sesuai Figma.
    var chipIconName: String {
        switch self {
        case .bedroom: return "bed.double"
        case .bathroom: return "shower"
        case .kitchen: return "stove"
        case .livingRoom: return "sofa"
        }
    }
}
