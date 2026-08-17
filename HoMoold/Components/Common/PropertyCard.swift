//
//  PropertyCard.swift
//  HoMoold
//
//  Kartu rumah di layar Inspection (Home). Ngikutin varian kartu paling ringkas
//  di Figma 1339:7023 — putih, radius 39, TANPA foto thumbnail.
//
//  Keputusan desain: thumbnail dibuang, dan mold risk yang jadi elemen paling
//  dominan. Alasannya foto ruangan random nggak ngasih info apa-apa buat orang
//  yang lagi milih-milih rumah — yang dia mau tau itu "rumah ini aman apa nggak",
//  dan itu si risk level. Jadi risk-nya dikasih tipografi paling gede di kartu.
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
            // Baris atas: identitas rumah di kiri, status risiko sebagai chip
            // di kanan. Chip-nya sengaja bukan teks gede kayak sebelumnya —
            // teks 22pt berwarna di pojok bikin kartunya kelihatan berat sebelah,
            // sementara chip kebaca sekilas tanpa mendominasi.
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

                riskChip
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

    /// Kalau belum ada ruangan yang diperiksa, tampilin "Not inspected" —
    /// BUKAN "Low". Belum diperiksa itu beda makna sama aman, dan nampilin
    /// "Low" di rumah yang belum dicek itu misleading.
    @ViewBuilder
    private var riskChip: some View {
        if let risk = property.overallRisk {
            HStack(spacing: 6) {
                Circle()
                    .fill(risk.color)
                    .frame(width: 7, height: 7)

                Text(risk.pillLabel)
                    .font(Theme.font.caption)
                    .foregroundStyle(risk.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(risk.color.opacity(0.12), in: Capsule())
        } else {
            Text("Not inspected")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.color.surfaceMuted, in: Capsule())
        }
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

    /// Baris jumlah ruangan per tipe, dipisah garis vertikal — sesuai Figma
    /// (ikon + angka, 13pt, pemisah hairline).
    private var roomCountRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(roomCounts.enumerated()), id: \.element.type) { index, entry in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.color.separator)
                        .frame(width: 1, height: 12)
                        .padding(.horizontal, 8)
                }

                Label {
                    Text("\(entry.count)")
                } icon: {
                    Image(systemName: entry.type.chipIconName)
                }
                .font(Theme.font.footnote)
                .foregroundStyle(Theme.color.textPrimary)
                .labelStyle(.titleAndIcon)
            }
        }
    }

    private var accessibilityDescription: String {
        let risk = property.overallRisk.map { "\($0.label) mold risk" } ?? "not inspected yet"
        return "\(property.name), \(property.location.displayText), \(risk)"
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
