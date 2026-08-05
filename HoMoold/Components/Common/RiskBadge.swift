//
//  RiskBadge.swift
//  HoMoold
//

import SwiftUI

struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.labelID)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(level.color, in: Capsule())
            .accessibilityLabel("Risiko \(level.labelID)")
    }
}

#Preview {
    HStack {
        RiskBadge(level: .low)
        RiskBadge(level: .medium)
        RiskBadge(level: .high)
    }
    .padding()
}
