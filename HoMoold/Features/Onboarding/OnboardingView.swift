//
//  OnboardingView.swift
//  HoMoold
//
//  Figma "Action Page" (1339:7008) — layar pertama waktu app dibuka.
//
//  Strukturnya: backdrop teal `#acd7d4` full screen, terus kartu mint `#EEFFFE`
//  yang nutupin hampir semuanya dengan dua sudut ATAS membulat 40pt. Backdrop
//  teal-nya cuma keliatan setipis strip di area status bar.
//
//  Ditampilkan lewat `fullScreenCover` dari RootView, BUKAN `sheet` — sudut
//  membulat di atas itu bagian dari desainnya, kalau pakai sheet jadi dobel
//  (sheet nambah sudutnya sendiri + nge-dim yang di belakang).
//
//  Catatan font: Figma pakai Plus Jakarta Sans Medium 14 buat teks value prop.
//  Di sini disubstitusi font sistem — SF Pro ikut Dynamic Type dan seirama sama
//  optical weight SF Symbol di sebelahnya. Kalau nanti Plus Jakarta Sans-nya
//  beneran mau dipakai, bundle file font-nya terus pakai
//  `.custom(_:size:relativeTo:)` biar tetap ikut Dynamic Type.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Theme.color.onboardingBackdrop
                .ignoresSafeArea()

            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Pembagian ruang pakai Spacer berbobot, bukan padding tetap —
            // proporsinya ngikutin Figma (logo di ~37% tinggi layar, value prop
            // mulai ~65%) tapi tetap aman di layar yang lebih pendek/panjang.
            Spacer()
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 30)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("HooMold")

            Spacer()
            Spacer()

            valueProps
                .padding(.horizontal, 40)

            Spacer()

            Button("Start") {
                withAnimation { hasSeenOnboarding = true }
            }
            .buttonStyle(.pillProminent)
            .padding(.horizontal, 22)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Sudut membulat cuma di atas — bawahnya nempel ke tepi layar.
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(Theme.color.onboardingSurface)
        }
        .padding(.top, 34)
        .ignoresSafeArea(edges: .bottom)
    }

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 25) {
            ForEach(ValueProp.all) { prop in
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: prop.symbol)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(prop.color)
                        .frame(width: 56, alignment: .leading)

                    Text(prop.text)
                        .font(Theme.font.subheadlineMedium)
                        .foregroundStyle(Theme.color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Value props

/// Copy & ikon diambil verbatim dari Figma. Teks kedua memang kepotong
/// gramatikanya ("Get to know if the house building condition") — dibiarin biar
/// sama kayak desain; gampang dibenerin di sini kalau copy-nya mau dirapiin.
private struct ValueProp: Identifiable {
    let id = UUID()
    var symbol: String
    var color: Color
    var text: String

    static let all: [ValueProp] = [
        ValueProp(
            symbol: "lungs",
            color: Theme.color.iconLungs,
            text: "Get to know if the mold in a house could get you sick"
        ),
        ValueProp(
            symbol: "house.badge.exclamationmark",
            color: Theme.color.iconHouseAlert,
            text: "Get to know if the house building condition"
        ),
    ]
}

#Preview {
    OnboardingView()
}
