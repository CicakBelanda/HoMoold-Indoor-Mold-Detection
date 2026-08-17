//
//  HeartbeatSymbol.swift
//  HoMoold
//
//  Ikon "hati dengan garis EKG" buat kartu Potential Health Risk.
//
//  SF Symbols NGGAK punya glyph gabungan ini — yang ada cuma `heart` (hati
//  polos) dan `waveform.path.ecg` (garis EKG doang). Jadi dua-duanya ditumpuk:
//  hati sebagai kerangka, garis EKG melintang di tengahnya. Hasilnya mirip
//  ikon di desain, tapi tetap berupa SF Symbol — ikut Dynamic Type, ke-tint
//  lewat `foregroundStyle`, dan nggak punya margin transparan kayak aset PNG
//  (yang dulu bikin ikonnya kelihatan mungil).
//
//  Kalau nanti butuh yang persis sama kayak Figma, aset rasternya masih ada di
//  riwayat git — tapi ini nggak perlu di-maintain per-resolusi.
//

import SwiftUI

struct HeartbeatSymbol: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Image(systemName: "heart")
                .font(.system(size: size, weight: .medium))

            // Garis EKG-nya sengaja dibikin lebih tebal (`.heavy`) dan selebar
            // ~62% hati: di ukuran segini, kalau setipis default garisnya ilang
            // ketelan outline hatinya.
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.62, weight: .heavy))
                // Digeser sedikit ke atas biar duduk di garis tengah hati,
                // bukan di titik pusat bounding box-nya (hati itu berat di atas).
                .offset(y: -size * 0.02)
        }
        // Digabung jadi satu elemen — VoiceOver nggak perlu tau ini dua simbol.
        .accessibilityElement()
    }
}

#Preview {
    HStack(spacing: 20) {
        HeartbeatSymbol()
            .foregroundStyle(.red)
            .frame(width: 56, height: 56)
            .background(Color("IconHealthBg"), in: RoundedRectangle(cornerRadius: 7))

        HeartbeatSymbol(size: 60)
            .foregroundStyle(.red)
    }
    .padding()
}
