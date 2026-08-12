//
//  PropertyCard.swift
//  HoMoold
//
//  Kartu rumah di Home — foto full-width di atas, nama/lokasi/tanggal, lalu baris
//  ikon jumlah kamar per tipe (bukan harga — sesuai desain Figma Home Detail Page).
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
        VStack(alignment: .leading, spacing: 10) {
            Image(uiImage: property.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(property.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(relativeDate(property.lastInspectionDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(property.location.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !roomCounts.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(roomCounts.enumerated()), id: \.element.type) { index, entry in
                        if index > 0 {
                            Divider().frame(height: 14)
                                .padding(.horizontal, 8)
                        }
                        Label {
                            Text("\(entry.count)")
                        } icon: {
                            Image(systemName: entry.type.chipIconName)
                        }
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Hari ini" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

#Preview {
    let room = RoomInspection(
        roomType: .bedroom, riskLevel: .medium, riskScore: 52, findings: [],
        hasAC: true, hasWindow: true, dampness: true, wallCrack: false, date: Date()
    )
    let property = KosProperty(
        name: "Kos Contoh", location: KosLocation(region: "Banten", city: "Tangerang", district: "Kec. Cisauk"),
        price: 850_000, rooms: [room]
    )
    return PropertyCard(property: property)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
