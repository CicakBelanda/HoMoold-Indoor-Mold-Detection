//
//  MoldReferenceView.swift
//  HoMoold
//
//  Figma 1339:7921 — referensi visual "yang mana jamur, yang mana bukan".
//
//  Ini jawaban buat masalah nyata: orang awam nggak bisa mbedain jamur, mildew,
//  dan sekadar noda lembap. Padahal bedanya penting — model cuma dilatih buat
//  jamur, jadi noda lembap yang difoto sebagai jamur bikin laporannya ngaco.
//
//  BUKAN bagian alur maju. Di-push dari GuidanceView, dari form kondisi, dan
//  dari tombol "?" di kamera — terus di-pop lagi. Makanya tombolnya "Got it".
//

import SwiftUI

struct MoldReferenceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                intro

                ForEach(MoldCategory.all) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        // URUTANNYA PENTING: `safeAreaInset` dulu, `background` belakangan.
        // Kalau dibalik, background-nya cuma nutup ScrollView — strip di bawah
        // tombol (area home indicator) nggak keikut, jadi kelihatan putih di
        // tengah layar yang gelap.
        .safeAreaInset(edge: .bottom) { bottomButton }
        .background { background }
        .navigationTitle("Mold or not?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Tiap lapis ignoresSafeArea sendiri — kalau scrim-nya dipasang sebagai
    /// `.overlay` di atas Image, dia ke-compose di ukuran yang masih kena safe
    /// area dan bagian atas layar nggak keredupin.
    private var background: some View {
        ZStack {
            Color.black

            Image("GuidanceBackground")
                .resizable()
                .scaledToFill()

            Theme.gradient.guidanceScrim
        }
        .ignoresSafeArea()
    }

    /// Satu kalimat pembuka. Tanpa ini halamannya langsung nyodorin tiga kartu
    /// tanpa ngasih tau kenapa bedanya penting.
    private var intro: some View {
        Text("Only mold should be photographed. Mildew and damp stains look similar, but they are recorded on the condition form instead.")
            .font(Theme.font.subheadline)
            .foregroundStyle(Theme.color.textOnDarkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
    }

    /// Tombolnya jadi bagian layout (lewat `safeAreaInset`), bukan lapisan
    /// ngambang — jadi nggak perlu gradient peredam sama sekali.
    ///
    /// Strip-nya dikasih HITAM SOLID yang nembus sampai bawah layar. Ini
    /// nyambung mulus karena `guidanceScrim` udah dibikin berakhir di hitam
    /// penuh — kalau scrim-nya masih berhenti di 65%, batas antara konten dan
    /// strip ini bakal kelihatan.
    private var bottomButton: some View {
        Button("Got it") { dismiss() }
            .buttonStyle(.pillProminent)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea(edges: .bottom))
    }

    private func categoryCard(_ category: MoldCategory) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.accent)
                    .frame(width: 8, height: 8)

                Text(category.title)
                    .font(Theme.font.title3Emphasized)
                    .foregroundStyle(Theme.color.textOnDark)

                Spacer(minLength: 0)

                // Penanda paling penting di layar ini: mana yang harus difoto.
                Text(category.shouldPhotograph ? "Photograph this" : "Don't photograph")
                    .font(Theme.font.caption)
                    .foregroundStyle(category.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(category.accent.opacity(0.18), in: Capsule())
            }

            sampleArea(category)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(category.traits) { trait in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.color.textOnDarkSecondary)
                            .frame(width: 4, height: 4)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(trait.label)
                                .font(Theme.font.headline)
                                .foregroundStyle(Theme.color.textOnDark)

                            if let detail = trait.detail {
                                Text(detail)
                                    .font(Theme.font.subheadline)
                                    .foregroundStyle(Theme.color.textOnDarkSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.color.textOnDark.opacity(0.14), lineWidth: 1)
        )
    }

    /// Mold pakai FOTO asli (283x183 di Figma) karena teksturnya yang harus
    /// dikenali. Mildew & Dampness pakai kartu contoh putih — bentuk dan
    /// warnanya yang dibandingin, bukan satu foto spesifik.
    @ViewBuilder
    private func sampleArea(_ category: MoldCategory) -> some View {
        switch category.samples {
        case .photo(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .swatches(let names):
            HStack(spacing: 12) {
                ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .padding(22)
                        .frame(height: 110)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.color.cardOnDark)
                        )
                }
            }
        }
    }
}

// MARK: - Categories

/// Copy verbatim dari Figma 1339:7921 / 1348:8811.
private struct MoldCategory: Identifiable {
    let id = UUID()
    var title: String
    var accent: Color
    /// Yang boleh difoto cuma jamur — dua lainnya justru bikin hasilnya ngaco.
    var shouldPhotograph: Bool
    var samples: Samples
    var traits: [Trait]

    enum Samples {
        case photo(String)
        case swatches([String])
    }

    struct Trait: Identifiable {
        let id = UUID()
        var label: String
        /// Keterangan tambahan. Cuma Mold yang punya di Figma — dua kategori
        /// lain ciri-cirinya ditulis sebagai satu frasa, jadi nggak dipecah
        /// paksa biar copy-nya nggak ngarang.
        var detail: String?
    }

    /// Warnanya ngikuti AKSI, bukan bahaya: hijau = ini yang difoto, merah =
    /// jangan difoto. Sempat kebalik (merah buat Mold karena "paling bahaya"),
    /// tapi di layar ini yang dibaca user itu "boleh apa nggak", bukan
    /// "seberapa parah" — dan itu bikin salah tangkap.
    static let all: [MoldCategory] = [
        MoldCategory(
            title: "Mold",
            accent: Theme.color.riskLow,
            shouldPhotograph: true,
            samples: .photo("MoldPhoto"),
            traits: [
                Trait(
                    label: "Raised, velvety texture",
                    detail: "Looks fuzzy or spotted, and sits on top of the surface. You can often see it catch the light from an angle."
                ),
                Trait(
                    label: "Grows into the material",
                    detail: "Spreads in irregular patches and eats into paint or plaster, so the edge looks ragged rather than a clean stain."
                ),
                Trait(
                    label: "Black, navy or dark green",
                    detail: "Deep, saturated colour. Often comes with a musty smell in the room."
                ),
            ]
        ),
        MoldCategory(
            title: "Mildew",
            accent: Theme.color.riskHigh,
            shouldPhotograph: false,
            samples: .swatches(["MoldSample", "MoldSample"]),
            traits: [
                Trait(
                    label: "Flat, powdery layer",
                    detail: "Sits flush against the wall like dust. Wipes away far more easily than mold."
                ),
                Trait(
                    label: "Stays on the surface",
                    detail: "Doesn't penetrate the material, so the wall underneath is still intact."
                ),
                Trait(
                    label: "White, gray or pale yellow",
                    detail: "Much lighter than mold, closer to chalk than to a dark stain."
                ),
            ]
        ),
        MoldCategory(
            title: "Dampness",
            accent: Theme.color.riskHigh,
            shouldPhotograph: false,
            samples: .swatches(["DampnessSample", "DampnessSample"]),
            traits: [
                Trait(
                    label: "Water staining and rings",
                    detail: "Smooth discolouration with a tide-line edge, like a coffee ring. No texture to it at all."
                ),
                Trait(
                    label: "Peeling paint or bubbling plaster",
                    detail: "The surface lifts or blisters because moisture is behind it, not growing on it."
                ),
                Trait(
                    label: "No fungal growth yet",
                    detail: "A warning sign, not mold. Tick \"Dampness\" on the condition form instead of photographing it."
                ),
            ]
        ),
    ]
}

#Preview {
    NavigationStack {
        MoldReferenceView()
    }
}
