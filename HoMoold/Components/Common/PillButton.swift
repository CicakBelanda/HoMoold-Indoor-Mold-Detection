//
//  PillButton.swift
//  HoMoold
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var isProminent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isProminent ? Color.white : Color.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isProminent ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillProminent: PillButtonStyle { PillButtonStyle(isProminent: true) }
    static var pillSecondary: PillButtonStyle { PillButtonStyle(isProminent: false) }
}
