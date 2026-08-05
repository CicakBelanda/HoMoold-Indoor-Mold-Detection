//
//  FindingClass.swift
//  HoMoold
//

import SwiftUI

enum FindingClass: String, Codable {
    case mold = "MOLD"
    case damp = "DAMP"
    case crack = "CRACK"

    var color: Color {
        switch self {
        case .mold: return .orange
        case .damp: return .yellow
        case .crack: return .red
        }
    }

    var displayNameID: String {
        switch self {
        case .mold: return "Jamur"
        case .damp: return "Lembap"
        case .crack: return "Retak"
        }
    }
}
