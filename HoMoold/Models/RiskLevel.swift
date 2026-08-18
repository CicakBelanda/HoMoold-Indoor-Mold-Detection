//
//  RiskLevel.swift
//  HoMoold
//

import SwiftUI

enum RiskLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    /// Lewat Theme, bukan `.green`/`.orange`/`.red` langsung — biar warna status
    /// di seluruh app ganti dari satu tempat.
    var color: Color {
        switch self {
        case .low: return Theme.color.riskLow
        case .medium: return Theme.color.riskMedium
        case .high: return Theme.color.riskHigh
        }
    }

    /// Petakan output RiskClassifier ("Low"/"Medium"/"High") ke enum ini.
    ///
    /// Ini SUMBER KEBENARAN buat risiko yang ditampilin ke user. Sebelumnya
    /// kartu ruangan pakai `level(forScore:)` yang dihitung dari JUMLAH FOTO
    /// (`findings.count * 12`) — dengan satu-dua foto hasilnya selalu di bawah
    /// 40, jadi semua ruangan kelihatan "Low" padahal report-nya bilang "High".
    static func level(fromClassifier label: String?) -> RiskLevel? {
        switch label?.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        default: return nil
        }
    }

    static func level(forScore score: Int) -> RiskLevel {
        switch score {
        case ..<40: return .low
        case 40..<70: return .medium
        default: return .high
        }
    }

    /// Label buat ditampilin ke user. Sama kayak `rawValue` sekarang, tapi
    /// dipisah biar `rawValue` tetap stabil sebagai kunci `Codable` — data yang
    /// udah kesimpan di properties.json ngandelin string "Low"/"Medium"/"High",
    /// jadi jangan ganti `rawValue` cuma buat ngubah tampilan.
    var label: String { rawValue }

    /// Urutan keparahan buat dibandingin (Low < Medium < High).
    ///
    /// Perlu dipisah karena `RiskLevel` itu enum ber-String, jadi nggak bisa
    /// di-`max()` gitu aja — dan mengurutkan berdasarkan rawValue malah bikin
    /// "High" < "Low" secara alfabet.
    var severityRank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    /// Teks di pil kartu ruangan. "Medium", bukan "Moderate" — istilahnya
    /// disamain sama `rawValue` dan sama output RiskClassifier, jadi cuma ada
    /// satu kata buat tingkat ini di seluruh app.
    var pillLabel: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
}
