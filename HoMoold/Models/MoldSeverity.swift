//
//  MoldSeverity.swift
//  HoMoold
//
//  Keparahan Jamur — ditentukan dari total luas noda jamur yang kedeteksi
//  (hasil ukur LiDAR, lihat RoomInspection.totalAreaCM2), bukan dari model.
//  Aturan (dari product):
//    - gak ada jamur / luas nil  → No Mold
//    - < 600 cm²                 → Level 1 - Light Mold
//    - 600–16400 cm²             → Level 2 - Moderate Mold
//    - > 16400 cm²               → Level 3 - Severe Mold
//

import SwiftUI

enum MoldSeverity {
    case none
    case level1
    case level2
    case level3

    /// Hitung keparahan dari total luas jamur (cm²). `nil` (gak ada yang
    /// berhasil diukur) dianggap No Mold.
    static func severity(fromAreaCM2 area: Double?) -> MoldSeverity {
        guard let area, area > 0 else { return .none }
        switch area {
        case ..<600:
            return .level1
        case 600..<16400:
            return .level2
        default:
            return .level3
        }
    }

    var title: String {
        switch self {
        case .none: return "No Mold"
        case .level1: return "Level 1 - Light Mold"
        case .level2: return "Level 2 - Moderate Mold"
        case .level3: return "Level 3 - Severe Mold"
        }
    }

    /// Level 0–3 buat input model RiskClassifier (`Mold`): none=0, L1=1, L2=2, L3=3.
    var level: Int {
        switch self {
        case .none: return 0
        case .level1: return 1
        case .level2: return 2
        case .level3: return 3
        }
    }

    var color: Color {
        switch self {
        case .none: return .gray
        case .level1: return .orange
        case .level2: return .orange
        case .level3: return .red
        }
    }
}
