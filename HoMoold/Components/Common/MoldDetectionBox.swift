//
//  MoldDetectionBox.swift
//  HoMoold
//
//  Kotak deteksi ala Figma 1339:7594: garis oranye 3pt + tag "MOLD" isi penuh
//  di pojok kanan atas kotak.
//
//  Beda dari `BoundingBoxOverlay` (yang warnanya per-kelas dan tanpa tag), dan
//  dipakai di dua tempat: kartu foto di Report dan preview full-screen-nya.
//

import SwiftUI

struct MoldDetectionBox: View {
    /// Normalized, origin kiri-atas (UIKit-style).
    let boundingBox: CGRect

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: boundingBox.minX * geo.size.width,
                y: boundingBox.minY * geo.size.height,
                width: boundingBox.width * geo.size.width,
                height: boundingBox.height * geo.size.height
            )

            Rectangle()
                .strokeBorder(Theme.color.riskMedium, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .overlay(alignment: .topTrailing) {
                    // Tag-nya kecil aja. Ini penanda, bukan judul — kalau
                    // kegedean malah nutupin jamur yang justru mau dilihat.
                    Text("MOLD")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.color.surfaceMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.color.riskMedium)
                        .offset(y: -17)
                }
                .position(x: rect.midX, y: rect.midY)
        }
    }
}
