//
//  RoomTagRow.swift
//  HoMoold
//

import SwiftUI

struct RoomTagRow: View {
    let roomType: RoomType
    let riskLevel: RiskLevel

    var body: some View {
        HStack {
            Label(roomType.rawValue, systemImage: roomType.iconName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            RiskBadge(level: riskLevel)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 8) {
        RoomTagRow(roomType: .bedroom, riskLevel: .high)
        RoomTagRow(roomType: .bathroom, riskLevel: .medium)
    }
    .padding()
}
