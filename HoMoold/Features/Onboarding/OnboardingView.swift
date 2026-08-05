//
//  OnboardingView.swift
//  HoMoold
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("HoMoold")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                valueProp(
                    text: "Tau risiko jamur kamarmu sebelum tanda tangan kontrak — dari tanda-tanda yang belum kelihatan."
                )
                valueProp(
                    text: "Dapat rekomendasi cara menangani dan mencegahnya ke depan."
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            Button {
                withAnimation { hasSeenOnboarding = true }
            } label: {
                Text("Let's Get Started!")
            }
            .buttonStyle(.pillProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private func valueProp(text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
