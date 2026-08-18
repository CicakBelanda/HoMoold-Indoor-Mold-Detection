//
//  KosProperty.swift
//  HoMoold
//

import UIKit

/// Lokasi rumah — diisi otomatis dari GPS waktu ruangan pertama diperiksa
/// (lihat LocationService + ConditionFormView).
struct HomeLocation {
    var street: String // nama jalan + nomor, mis. "Jl. Anggrek No. 12"
    var region: String // provinsi
    var city: String // kota/kabupaten
    var district: String // kecamatan

    init(street: String = "", region: String, city: String, district: String) {
        self.street = street
        self.region = region
        self.city = city
        self.district = district
    }

    var isEmpty: Bool {
        street.isEmpty && region.isEmpty && city.isEmpty && district.isEmpty
    }

    /// Alamat selengkap yang ada, mis.
    /// "Jl. Anggrek No. 12, Kec. Cisauk, Tangerang, Banten".
    ///
    /// Bagian yang kosong dilewatin, jadi nggak ada koma nyangkut kalau GPS-nya
    /// cuma dapat sebagian.
    var displayText: String {
        let parts = [street, district, city, region].filter { !$0.isEmpty }
        return parts.isEmpty ? "No location yet" : parts.joined(separator: ", ")
    }
}

/// Codable ditulis manual — `street` ditambahin belakangan, dan sintesis
/// otomatis Swift NGGAK pakai nilai default kalau kuncinya nggak ada di JSON.
/// Tanpa `decodeIfPresent`, semua data lama gagal di-load begitu field ini
/// masuk.
extension HomeLocation: Codable {
    private enum CodingKeys: String, CodingKey {
        case street, region, city, district
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        street = try container.decodeIfPresent(String.self, forKey: .street) ?? ""
        region = try container.decode(String.self, forKey: .region)
        city = try container.decode(String.self, forKey: .city)
        district = try container.decode(String.self, forKey: .district)
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

    var lastInspectionDate: Date {
        rooms.map(\.date).max() ?? Date()
    }

    /// Risiko keseluruhan rumah = risiko ruangan TERPARAH, bukan rata-rata.
    ///
    /// Sengaja pakai max: satu kamar mandi yang jamurnya parah itu masalah nyata
    /// buat calon penyewa, dan kalau dirata-ratakan sama kamar-kamar bersih
    /// malah ketutupan. `nil` artinya belum ada ruangan yang diperiksa — beda
    /// makna sama "risiko rendah", jadi jangan di-default ke `.low`.
    var overallRisk: RiskLevel? {
        // Diambil dari `riskLevel` tiap ruangan — yaitu nilai yang SAMA dengan
        // yang ditampilin di kartu ruangan (hasil RiskClassifier).
        //
        // Dulu ini ngitung dari `riskScore`, padahal `riskScore` itu skor lama
        // `min(95, jumlahFoto * 12)` yang udah nggak dipakai buat nampilin
        // apa-apa. Efeknya: ruangan bisa ketulis "High Risk" (dari model) tapi
        // rumahnya ketulis "Low", karena skor jumlah-fotonya cuma 12.
        rooms.map(\.riskLevel).max { $0.severityRank < $1.severityRank }
    }

    var priceText: String? {
        guard let price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "Rp \(formatted) / month"
    }
}
