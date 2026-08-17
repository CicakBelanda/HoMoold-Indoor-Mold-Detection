//
//  CheckboxRow.swift
//  HoMoold
//
//  Baris label + checkbox, dipakai di kartu Availability & Conditions
//  (Figma 1339:7292).
//
//  Sengaja checkbox, BUKAN `Toggle`. Di desainnya kotak 24pt radius 6: hijau
//  penuh + centang putih kalau nyala, kotak kosong bergaris abu kalau mati.
//  Switch bawaan iOS bentuknya beda jauh, jadi ini salah satu kasus di mana
//  desainnya memang beda dari kontrol sistem — bukan sekadar niru tampilan
//  yang udah dikasih sistem.
//
//  Tetap pakai `Button` + trait `.isToggle` biar VoiceOver/Switch Control
//  ngebacanya tetap sebagai kontrol dua-keadaan.
//

import SwiftUI

struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                checkbox
            }
            // Figma: isi baris 31pt, pitch ~54. Di sini padding-nya dinaikin
            // jadi 15 (pitch 61) — nilai persis Figma kerasa sempit di layar
            // beneran. Padding ditaruh di BARIS, bukan di divider: keliatannya
            // sama, tapi area tap-nya jadi 61pt (lewat minimum 44pt Apple),
            // sementara kalau di divider area tap-nya cuma setinggi teks.
            .frame(height: 31)
            .padding(.vertical, 15)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isOn ? Theme.color.checkboxOn : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isOn ? Theme.color.checkboxOn : Theme.color.checkboxOff,
                        lineWidth: 1
                    )
            }
            .overlay {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
            .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// Kartu putih pembungkus beberapa `CheckboxRow`, dengan hairline pemisah
/// antar baris — persis kayak kartu di Figma (radius 20, padding 10).
struct CheckboxCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        // Vertikal 0 karena tiap baris udah bawa padding sendiri — kalau
        // ditambah lagi di sini, baris pertama & terakhir jadi kelebihan ruang
        // dibanding jarak antar baris.
        .padding(.horizontal, 16)
        .background(
            Theme.color.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

private struct CheckboxPreview: View {
    @State private var ac = true
    @State private var window = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Availability")
                .font(Theme.font.headline)

            CheckboxCard {
                CheckboxRow(title: "AC", isOn: $ac)
                Divider()
                CheckboxRow(title: "Window", isOn: $window)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.color.surfaceMuted)
    }
}

#Preview {
    CheckboxPreview()
}
