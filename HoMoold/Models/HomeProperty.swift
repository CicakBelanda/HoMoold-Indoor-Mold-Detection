//
//  KosProperty.swift
//  HoMoold
//

import UIKit

/// Lokasi kos, diisi manual sama user di form Location (dengan prefill dari
/// GPS kalau berhasil — lihat LocationService), bukan diam-diam auto-fill.
struct HomeLocation: Codable {
    var region: String // provinsi
    var city: String // kota/kabupaten
    var district: String // kecamatan

    var isEmpty: Bool { region.isEmpty && city.isEmpty && district.isEmpty }

    /// Teks ringkas buat ditampilin di card/list, mis. "Kec. Cisauk, Tangerang".
    var displayText: String {
        let parts = [district, city].filter { !$0.isEmpty }
        return parts.isEmpty ? "Lokasi belum diisi" : parts.joined(separator: ", ")
    }
}

/// `Codable` disintesis otomatis compiler — `thumbnail` di bawah itu computed
/// property (bukan stored), jadi diabaikan sama sintesis Codable, gak perlu
/// custom encode/decode kayak `Finding`/`RoomInspection` yang punya UIImage
/// sebagai STORED property.
struct KosProperty: Identifiable, Codable {
    let id = UUID()
    var name: String
    var location: HomeLocation
    var price: Int? // harga sewa (Rp/bulan), nil = belum diisi
    var rooms: [RoomInspection]

    /// Kos dibuat dulu lewat "Save a house" (nama doang), ruangan nyusul lewat
    /// "Tambah Ruangan" — jadi belum tentu ada foto pas properti baru dibuat.
    /// Diambil dari ruangan pertama yang punya foto, fallback ke ilustrasi
    /// rumah generik (lihat PlaceholderImageFactory).
    var thumbnail: UIImage {
        rooms.first?.thumbnail ?? PlaceholderImageFactory.houseOutline()
    }

    var lastInspectionDate: Date {
        rooms.map(\.date).max() ?? Date()
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
