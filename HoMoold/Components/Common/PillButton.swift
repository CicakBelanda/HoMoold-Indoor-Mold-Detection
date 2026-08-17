//
//  PillButton.swift
//  HoMoold
//
//  Tombol utama sesuai Figma: capsule tinggi 48pt, radius 32, gradient
//  horizontal `#00786c` → `rgba(0,222,200,0.75)`, label 17pt Semibold putih.
//  Nilai warnanya ada di Theme.gradient.primaryButton.
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    enum Variant {
        /// Aksi utama — kapsul gradient, label putih.
        case prominent
        /// Aksi sekunder — kapsul abu, label teal brand.
        case secondary
        /// Aksi batal di dalam modal — kapsul abu, label HITAM. Bukan teal:
        /// di modal dua tombol, Cancel yang berwarna brand kelihatan sama
        /// pentingnya sama tombol utamanya.
        case modalSecondary
    }

    var variant: Variant = .prominent

    private var labelColor: Color {
        switch variant {
        case .prominent: return Theme.color.textOnDark
        case .secondary: return Theme.color.brand
        case .modalSecondary: return Theme.color.textPrimary
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font.buttonLabel)
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Metric.buttonHeight)
            .background {
                switch variant {
                case .prominent:
                    Capsule().fill(Theme.gradient.primaryButton)
                case .secondary, .modalSecondary:
                    Capsule().fill(Theme.color.modalFieldFill)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillProminent: PillButtonStyle { PillButtonStyle(variant: .prominent) }
    static var pillSecondary: PillButtonStyle { PillButtonStyle(variant: .secondary) }
    static var pillModalSecondary: PillButtonStyle { PillButtonStyle(variant: .modalSecondary) }
}
