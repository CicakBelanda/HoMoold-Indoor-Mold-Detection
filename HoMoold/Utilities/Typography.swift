//
//  Typography.swift
//  HoMoold
//

import SwiftUI

extension Theme {
    static let font = Typography()

    struct Typography {
        // MARK: Judul

        /// Figma `Large Title/Regular` — SF Pro 34/41 Regular.
        let largeTitle = Font.largeTitle

        /// Figma `Title1/Emphasized` — SF Pro 28/34 Bold.
        let title = Font.title.weight(.bold)

        /// Figma `Title2/Regular` — SF Pro 22/28 Regular.
        /// Ini judul utama tiap halaman Guidance.
        let title2 = Font.title2

        /// Judul tebal buat header layar non-Figma (Home, Report).
        let title2Emphasized = Font.title2.weight(.bold)

        let title3 = Font.title3

    /// Judul modal ("Add New House") — 20pt Bold.
    let title3Emphasized = Font.title3.weight(.bold)

    /// Nama rumah di kartu Inspection — 20pt Semibold. Naik dari `.headline`
    /// (17pt): nama rumah itu yang dicari mata pertama kali di daftar, jadi
    /// harus jelas lebih besar dari alamat di bawahnya.
    let cardTitle = Font.title3.weight(.semibold)

        // MARK: Body

        /// Figma `Body/Emphasized` — SF Pro 17/22 Semibold. 17pt Semibold itu
        /// definisi `.headline`, jadi pakai itu, bukan `.body.semibold()`.
        let headline = Font.headline

        /// Figma `Body/Regular` — SF Pro 17/22 Regular.
        let body = Font.body

        /// Caption Loading Page di Figma 16pt → `.callout`.
        let callout = Font.callout

        let subheadline = Font.subheadline

        /// Teks value prop di onboarding — Figma: Plus Jakarta Sans Medium 14pt.
        /// 14pt persis nggak ada padanan text style-nya (footnote 13, subheadline
        /// 15), jadi ambil subheadline + weight medium: paling dekat dan tetap
        /// ikut Dynamic Type. Lihat catatan font di OnboardingView.
        let subheadlineMedium = Font.subheadline.weight(.medium)

        let footnote = Font.footnote
        let caption = Font.caption

        // MARK: Kombinasi yang sering dipakai

        /// Label tombol utama — Figma: 17pt Semibold.
        let buttonLabel = Font.headline
    }
}

extension Theme.Typography {
    /// Judul layar Report — Figma 1339:7594 pakai 24pt Medium, di antara
    /// `.title2` (22) dan `.title` (28). Ambil `.title2` + weight medium.
    var screenTitle: Font { Font.title2.weight(.medium) }

    /// Angka besar "Medium Rate" di kartu prediksi.
    ///
    /// Figma nulis 36pt, tapi di layar beneran itu terlalu dominan — teksnya
    /// hampir selebar kartunya. Diturunin ke `.title` (28pt) Semibold: masih
    /// jelas elemen paling besar di kartu, tapi nggak nabrak chevron.
    var statValue: Font { Font.title.weight(.semibold) }

    /// Isi bullet di kartu Health Risk / Recommendations.
    ///
    /// Figma nulis `Title3/Emphasized` (20pt), tapi di layar beneran itu
    /// kegedean — bullet-nya jadi lebih dominan daripada angka prediksi di
    /// kartu atasnya, padahal harusnya sebaliknya. Diturunin ke 17pt Semibold
    /// (`.headline`).
    var bulletItem: Font { Font.subheadline.weight(.semibold) }

    /// Label abu di atas isi kartu. Figma nulis 17pt; diturunin ke
    /// `.subheadline` (15pt) supaya jelas jadi label, bukan isi.
    var cardLabel: Font { Font.subheadline }
}
