//
//  PropertyCard.swift
//  HoMoold
//

import SwiftUI

struct PropertyCard: View {
    let property: KosProperty

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: property.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(property.rooms.prefix(2)) { room in
                    RoomTagRow(roomType: room.roomType, riskLevel: room.riskLevel)
                }

                if property.anyRoomHasAC || property.anyRoomHasWindow {
                    HStack(spacing: 6) {
                        if property.anyRoomHasWindow {
                            AmenityBadge(icon: "window.casement", label: "Jendela")
                        }
                        if property.anyRoomHasAC {
                            AmenityBadge(icon: "wind", label: "AC")
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(property.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack {
                        Text(property.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(relativeDate(property.lastInspectionDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let priceText = property.priceText {
                        Text(priceText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

private struct AmenityBadge: View {
    let icon: String
    let label: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}

#Preview {
    PropertyCard(property: DummyDataFactory.seedProperties()[0])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
