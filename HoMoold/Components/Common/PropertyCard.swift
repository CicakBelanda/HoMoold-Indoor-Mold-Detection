//
//  PropertyCard.swift
//  HoMoold
//
//  Kartu rumah di layar Inspection (Home). Ngikutin varian kartu paling ringkas
//  di Figma 1339:7023 — putih, radius 39, TANPA foto thumbnail.
//
//  Keputusan desain: thumbnail dibuang. Risiko juga NGGAK ditampilin di sini —
//  satu rumah bisa punya beberapa ruangan dengan tingkat yang beda-beda, dan
//  meringkasnya jadi satu angka di kartu bikin rumah yang punya satu ruangan
//  parah kebaca sama aja kayak yang semua ruangannya aman. Tingkatnya
//  ditampilin per-ruangan di halaman detail rumah, di tempat yang angkanya
//  beneran berlaku.
//
//  Nggak ada drop shadow — kartu putih di atas gradient teal udah cukup kebaca
//  sebagai kartu, dan shadow-nya bikin terlalu dramatis.
//

import SwiftUI

struct PropertyCard: View {
    let property: KosProperty

    private var roomCounts: [(type: RoomType, count: Int)] {
        RoomType.allCases.compactMap { type in
            let count = property.rooms.filter { $0.roomType == type }.count
            return count > 0 ? (type, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Baris atas: identitas rumah. `Spacer` di ujungnya dipertahankan
            // supaya teks panjang berhenti di lebar kartu, bukan mendorong
            // kartunya melar.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(property.name)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.textPrimary)
                        .lineLimit(1)

                    // Dua baris — alamat lengkapnya sekarang termasuk nama
                    // jalan, jadi satu baris hampir pasti kepotong.
                    Text(property.location.displayText)
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            // Baris bawah cuma muncul kalau rumahnya udah punya ruangan — kalau
            // belum, isinya bakal kosong semua.
            if !property.rooms.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    if !roomCounts.isEmpty {
                        roomCountRow
                    }

                    Spacer(minLength: 8)

                    lastUpdatedLabel
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    /// Kapan terakhir kali rumah ini diperiksa. Nggak ditampilin kalau belum
    /// ada ruangan sama sekali — `lastInspectionDate` jatuh ke `Date()` waktu
    /// kosong, dan itu bakal kebaca "Today" buat rumah yang belum pernah dicek.
    @ViewBuilder
    private var lastUpdatedLabel: some View {
        if !property.rooms.isEmpty {
            Text(relativeDate(property.lastInspectionDate))
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)
                // Yang ngalah duluan kalau baris ini kesempitan — tanggal
                // kepotong masih kebaca, jumlah kamar yang ilang enggak.
                .lineLimit(1)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days) days ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "d MMM"
            : "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Jumlah ruangan per tipe, satu chip per tipe.
    ///
    /// Dulu ikon + angka polos yang cuma dipisah jarak, dan itu masalahnya:
    /// jarak DI DALAM satu pasang (ikon↔angka) hampir sama dengan jarak ANTAR
    /// pasang, jadi sekilas nggak jelas angka "1" itu punya ikon di kirinya
    /// atau di kanannya. Dibungkus kapsul, batas tiap kelompoknya jadi nggak
    /// bisa salah baca.
    ///
    /// Kapsulnya idiom yang sama dengan chip kondisi di kartu ruangan
    /// (PropertyDetailView) — dua-duanya "beberapa fakta kecil sejajar".
    private var roomCountRow: some View {
        HStack(spacing: 6) {
            ForEach(roomCounts, id: \.type) { entry in
                roomCountChip(type: entry.type, count: entry.count)
            }
        }
        // INI yang bikin angkanya kadang ilang.
        //
        // Ikon itu ukurannya tetap, tapi `Text` angkanya lentur. Waktu rumahnya
        // punya empat tipe ruangan, baris ini plus tanggal di kanan kelebihan
        // lebar — dan yang dikorbanin SwiftUI ya yang lentur: angkanya
        // dikompres sampai nol lebar, jadi yang kelihatan tinggal ikonnya
        // doang. Yang kena bisa acak, makanya kelihatan kayak muncul-nggak-muncul.
        //
        // `fixedSize` bikin chip-nya nggak bisa diciutin sama sekali. Kalau
        // ruangnya beneran kurang, yang ngalah tanggalnya (lihat
        // `lastUpdatedLabel`) — itu info yang jauh lebih bisa ditebak user
        // daripada jumlah kamar.
        .fixedSize(horizontal: true, vertical: false)
    }

    private func roomCountChip(type: RoomType, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.chipIconName)
                .font(.caption)
                // Ikonnya beda-beda lebar (`sofa` jauh lebih lebar dari
                // `shower`), dan itu bikin chip-nya kelihatan nggak serata.
                // Dikasih lebar tetap biar semua chip sama bentuknya.
                .frame(width: 16)

            Text("\(count)")
                // `monospacedDigit` biar lebarnya nggak goyang waktu angkanya
                // berubah 1 -> 2 -> 10.
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.color.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.color.fieldFill, in: Capsule())
    }

    private var accessibilityDescription: String {
        // Rinciannya dibacain per tipe — chip-nya ada di dalam elemen gabungan,
        // jadi label masing-masing nggak kebaca sendiri-sendiri.
        let roomText: String
        if roomCounts.isEmpty {
            roomText = "no rooms yet"
        } else {
            roomText = roomCounts
                .map { "\($0.count) \($0.type.rawValue.lowercased())" }
                .joined(separator: ", ")
        }
        return "\(property.name), \(property.location.displayText), \(roomText)"
    }
}

#Preview {
    let room = RoomInspection(
        roomType: .bedroom, riskLevel: .medium, riskScore: 52, findings: [],
        hasAC: true, hasWindow: true, dampness: true, wallCrack: false, date: Date()
    )
    let inspected = KosProperty(
        name: "Sample House",
        location: HomeLocation(region: "Banten", city: "Tangerang", district: "Kec. Cisauk"),
        price: 850_000, rooms: [room]
    )
    let fresh = KosProperty(
        name: "House Melati",
        location: HomeLocation(region: "", city: "", district: ""),
        price: nil, rooms: []
    )
    return VStack(spacing: 14) {
        PropertyCard(property: inspected)
        PropertyCard(property: fresh)
    }
    .padding()
    .background(Theme.gradient.home)
}
