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

/// Urutan daftar rumah di layar Inspection.
///
/// Sortir berdasarkan risiko dibuang: kartu rumah nggak nampilin tingkat risiko
/// lagi (lihat PropertyCard), jadi user bakal ngurutin pakai sesuatu yang
/// hasilnya nggak bisa dia lihat sendiri di layar.
///
/// Sisanya dibikin BERPASANGAN — tiap sumbu punya dua arah, biar nggak ada
/// pilihan yang cuma satu arah tanpa kebalikannya.
enum HomeSortOrder: String, CaseIterable, Identifiable {
    case recent
    case oldest
    case nameAscending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return "Newest first"
        case .oldest: return "Oldest first"
        case .nameAscending: return "Name (A–Z)"
        }
    }

    var symbol: String {
        switch self {
        case .recent: return "arrow.down"
        case .oldest: return "arrow.up"
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
        case .medium: return "Medium"
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

    /// Ruangan SELALU punya hasil (dibuat lewat alur inspeksi), jadi
    /// "Not inspected" nggak pernah kena apa-apa di daftar ruangan — chip-nya
    /// ikut dibuang di `roomCases`.
    func matches(_ room: RoomInspection) -> Bool {
        switch self {
        case .all:
            return true
        case .notInspected:
            return false
        case .high, .medium, .low:
            return room.riskLevel == matchingLevel
        }
    }

    /// Chip yang dipakai di daftar ruangan.
    static let roomCases: [HomeRiskFilter] = [.all, .high, .medium, .low]
}

extension Array where Element == RoomInspection {
    /// Saringan risiko sekarang tinggal di daftar RUANGAN (di bawah tombol
    /// "Add new Room"), bukan di daftar rumah — di situ yang disaring memang
    /// hasil per ruangan, bukan rata-rata satu rumah.
    func filtered(by riskFilter: HomeRiskFilter) -> [RoomInspection] {
        filter { riskFilter.matches($0) }
    }
}

extension Array where Element == KosProperty {
    /// Cuma nyaring teks pencarian. Saringan risikonya udah pindah ke daftar
    /// ruangan — lihat `Array<RoomInspection>.filtered(by:)`.
    func filtered(bySearchText searchText: String) -> [KosProperty] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return self }
        return filter { property in
            property.name.localizedCaseInsensitiveContains(trimmed)
                || property.location.displayText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func sorted(by order: HomeSortOrder) -> [KosProperty] {
        switch order {
        case .recent:
            return sorted { $0.lastInspectionDate > $1.lastInspectionDate }
        case .oldest:
            return sorted { $0.lastInspectionDate < $1.lastInspectionDate }
        case .nameAscending:
            return sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}
