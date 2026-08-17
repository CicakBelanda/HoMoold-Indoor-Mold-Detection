//
//  OnboardingView.swift
//  HoMoold
//
//  Ditampilkan sebagai sheet (bukan full screen) di atas HomeListView pas
//  pertama kali buka app — lihat RootView. Copy & ikon sesuai Figma "Action Page".
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("HoMoold")

            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                valueProp(
                    icon: "lungs", iconColor: Color(red: 0.42, green: 0.78, blue: 0.51),
                    text: "Check first whether the mold risk in the house could make you sick"
                )
                valueProp(
                    icon: "house.badge.exclamationmark", iconColor: Color(red: 0, green: 0.43, blue: 0.71),
                    text: "Also know the building's condition before signing the lease"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            Button {
                withAnimation { hasSeenOnboarding = true }
            } label: {
                Text("LET'S START!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(colors: [Color("HoomoldDarkTeal"), Color("HoomoldTeal")], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func valueProp(icon: String, iconColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    OnboardingView()
}
