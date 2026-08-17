//
//  HomeListSorting.swift
//  HoMoold
//
//  Urutan & saringan buat daftar rumah di layar Inspection.
//
//  Dipisah dari view-nya biar logikanya bisa dibaca (dan dites) tanpa nyentuh
//  UI, dan biar HomeListView nggak numpuk jadi satu file panjang.
//

import Foundation

enum HomeSortOrder: String, CaseIterable, Identifiable {
    case recent
    case riskHighest
    case riskLowest
    case nameAscending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return "Last updated"
        case .riskHighest: return "Highest risk"
        case .riskLowest: return "Lowest risk"
        case .nameAscending: return "Name (A–Z)"
        }
    }

    var symbol: String {
        switch self {
        case .recent: return "clock"
        case .riskHighest: return "arrow.down.right"
        case .riskLowest: return "arrow.up.right"
        case .nameAscending: return "textformat"
        }
    }
}

enum HomeRiskFilter: String, CaseIterable, Identifiable {
    case all
    case high
    case medium
    case low
    case notInspected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All houses"
        case .high: return "High"
        case .medium: return "Moderate"
        case .low: return "Low"
        case .notInspected: return "Not inspected"
        }
    }

    /// Level yang cocok sama saringan ini. `nil` = saringannya bukan soal level
    /// (mis. "All" atau "Not inspected").
    var matchingLevel: RiskLevel? {
        switch self {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .all, .notInspected: return nil
        }
    }

    func matches(_ property: KosProperty) -> Bool {
        switch self {
        case .all:
            return true
        case .notInspected:
            return property.overallRisk == nil
        case .high, .medium, .low:
            return property.overallRisk == matchingLevel
        }
    }
}

extension Array where Element == KosProperty {
    /// Saring lalu urutkan. Urutannya sengaja begini: menyaring dulu bikin
    /// pengurutan cuma jalan di sisa datanya.
    /// Parameternya `riskFilter`, bukan `filter` — nama `filter` bakal nutupin
    /// method `Array.filter` di dalam badan fungsinya sendiri.
    func filtered(by riskFilter: HomeRiskFilter, searchText: String) -> [KosProperty] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        return filter { property in
            guard riskFilter.matches(property) else { return false }
            guard !trimmed.isEmpty else { return true }
            return property.name.localizedCaseInsensitiveContains(trimmed)
                || property.location.displayText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func sorted(by order: HomeSortOrder) -> [KosProperty] {
        switch order {
        case .recent:
            return sorted { $0.lastInspectionDate > $1.lastInspectionDate }
        case .nameAscending:
            return sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .riskHighest:
            return sortedByRisk(descending: true)
        case .riskLowest:
            return sortedByRisk(descending: false)
        }
    }

    /// Urut berdasarkan risiko.
    ///
    /// Yang BELUM DIPERIKSA selalu ditaruh paling bawah — di kedua arah. Bukan
    /// dianggap risiko nol: "belum dicek" beda sama "aman", jadi kalau diurut
    /// dari terendah pun dia nggak boleh nangkring di atas rumah yang beneran
    /// Low.
    private func sortedByRisk(descending: Bool) -> [KosProperty] {
        sorted { lhs, rhs in
            let l = lhs.overallRisk?.severityRank
            let r = rhs.overallRisk?.severityRank

            switch (l, r) {
            case (nil, nil):
                return lhs.lastInspectionDate > rhs.lastInspectionDate
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (l?, r?):
                if l == r { return lhs.lastInspectionDate > rhs.lastInspectionDate }
                return descending ? l > r : l < r
            }
        }
    }
}
