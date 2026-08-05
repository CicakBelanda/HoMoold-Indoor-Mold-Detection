//
//  RoomType.swift
//  HoMoold
//

import Foundation

enum RoomType: String, CaseIterable, Identifiable, Codable {
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
}
