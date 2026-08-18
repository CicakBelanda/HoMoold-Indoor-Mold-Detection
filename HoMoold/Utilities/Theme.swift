//
//  Theme.swift
//  HoMoold
//
//  Satu tempat buat semua warna yang dipakai di app. Aturannya:
//
//  1. Warna yang di Figma pakai token semantik Apple ("Labels/Primary",
//     "Backgrounds/Primary", "Grays/Gray 3", "Accents/Green", ...) DIPETAKAN ke
//     warna sistem SwiftUI, bukan di-hardcode hex-nya. Alasannya: file Figma-nya
//     pakai Apple UI Kit resmi, jadi hex yang keliatan di Figma itu cuma *nilai
//     render* token sistem di light mode. Hardcode hex-nya bikin dark mode,
//     Increase Contrast, dan Smart Invert rusak — padahal gratis kalau pakai
//     warna sistem.
//
//  2. Warna yang beneran milik brand HooMold (teal, gradient tombol, surface
//     loading) disimpan sebagai color set di Assets.xcassets, dinamain sama
//     kayak perannya, terus diakses lewat sini. Jangan tulis `Color(red:...)`
//     inline di view — nilainya jadi kesebar dan susah diubah.
//
//  Kalau nambah warna baru: cek dulu ada nggak padanan sistemnya. Kalau ada,
//  pakai itu. Bikin color set baru cuma buat warna yang beneran brand.
//

import SwiftUI

enum Theme {}

// MARK: - Warna

extension Theme {
    /// Warna brand + peran semantik. Diakses `Theme.color.<peran>`.
    static let color = Palette()

    struct Palette {
        // MARK: Brand

        /// Teal utama HooMold — juga dipasang sebagai `AccentColor`, jadi kontrol
        /// sistem (Toggle, ProgressView, tombol) ngambil ini otomatis. Jarang
        /// perlu dipanggil manual; biarin diwarisin.
        let brand = Color("HoomoldTeal")
        let brandDark = Color("HoomoldDarkTeal")

        /// Gradient tombol utama, dari Figma: `#00786c` → `rgba(0,222,200,0.75)`,
        /// arah kiri→kanan. Dipakai lewat `Theme.gradient.primaryButton`.
        let brandGradientStart = Color("BrandGradientStart")
        let brandGradientEnd = Color("BrandGradientEnd")

        /// Gradient mint→teal buat layar Home/Detail rumah.
        let homeGradientTop = Color("HomeGradientTop")
        let homeGradientBottom = Color("HomeGradientBottom")

        // MARK: Surface

        /// `#f7f7f7` — abu-abu tipis yang Figma pakai sebagai latar layar penuh
        /// (Loading Page dan Condition Page). Sengaja BUKAN `.systemBackground`:
        /// desainnya minta beda tipis dari putih, karena kartu di atasnya PUTIH
        /// dan butuh kontras.
        let surfaceMuted = Color("SurfaceLoading")

        /// Kartu putih di atas `surfaceMuted` (kartu Availability & Conditions).
        let card = Color.white

        /// Isian field Type/Name di Condition Page —
        /// `rgba(116,116,128,0.08)` di Figma itu token `fills/quaternary` Apple.
        let fieldFill = Color(uiColor: .quaternarySystemFill)

        /// Isian field di dalam modal. Lebih pekat dari `fieldFill` karena
        /// kartunya sendiri udah abu muda — pakai fill yang sama bikin field-nya
        /// nyaris nggak keliatan.
        let modalFieldFill = Color(uiColor: .systemGray5)

        /// Checkbox kecentang — token "Accents/Green" Figma.
        let checkboxOn = Color.green
        /// Garis checkbox belum kecentang — token "Grays/Gray" (`#8e8e93`).
        let checkboxOff = Color(uiColor: .systemGray)

        /// Onboarding / "Action Page": backdrop teal `#acd7d4` dengan kartu mint
        /// `#EEFFFE` di atasnya (sudut atas membulat 40pt).
        let onboardingBackdrop = Color("OnboardingBackdrop")
        let onboardingSurface = Color("OnboardingSurface")

        /// Latar layar biasa & layar berkelompok. Ini token sistem, dan memang
        /// sengaja — Figma pakai "Backgrounds/Primary".
        let surface = Color(uiColor: .systemBackground)
        let surfaceSecondary = Color(uiColor: .secondarySystemBackground)
        let surfaceGrouped = Color(uiColor: .systemGroupedBackground)

        /// Kartu putih di layar guidance (contoh jamur vs lembap) — di Figma
        /// token-nya "Grays/White", putih solid di atas foto gelap, jadi ini
        /// bukan `.systemBackground` yang ikut berubah.
        let cardOnDark = Color.white

        /// Kartu kategori di layar referensi jamur — `#e5e5ea` (Grays/Gray 5).
        let referenceCard = Color("ReferenceCardBg")
        /// Judul kategori di kartu itu — teal `#00786c`, sama kayak ujung awal
        /// gradient tombol utama.
        let referenceCardTitle = Color("BrandGradientStart")

        // MARK: Teks

        let textPrimary = Color.primary
        let textSecondary = Color.secondary

        /// Teks di atas surface gelap (layar guidance yang latarnya foto ruangan).
        /// Nggak boleh pakai `.primary`/`.secondary` di sini — layar-layar itu
        /// gelap sementara app-nya dipaksa light mode, jadi warna sistem malah
        /// jadi gelap-di-atas-gelap alias nggak kebaca.
        let textOnDark = Color.white
        let textOnDarkSecondary = Color("TextOnDarkSecondary")

        /// Caption abu-abu di Loading Page (`#6e6e6e`).
        let textMuted = Color("TextMuted")

        // MARK: Ikon

        /// Warna ikon value prop di onboarding — dari Figma, per-ikon (`#6cc782`
        /// buat `lungs`, `#016db6` buat `house.badge.exclamationmark`). Sengaja
        /// nggak dijadiin AccentColor: ini warna satu elemen, bukan tint app.
        let iconLungs = Color("IconLungs")
        let iconHouseAlert = Color("IconHouseAlert")

        // MARK: Status risiko

        /// Dari token "Accents/*" Figma → padanan sistemnya. `RiskLevel` bebas
        /// mapping ke sini.
        let riskLow = Color.green
        /// `#ff8d28` — oranye khusus dari Figma buat "Moderate/Medium Rate" dan
        /// kotak deteksi MOLD. Bukan `.orange` sistem: nilainya beda keliatan
        /// dan ini dipakai sebagai warna brand buat status risiko sedang.
        let riskMedium = Color("RiskModerate")
        let riskHigh = Color.red

        // MARK: Tile ikon kartu Report

        /// Tile ikon di kartu Report (49pt, radius 7) — warnanya per-kartu,
        /// diambil dari Figma 1339:7594.
        let iconHealthBackground = Color("IconHealthBg")
        let iconHealthForeground = Color.red
        let iconAdviceBackground = Color("IconAdviceBg")
        let iconAdviceForeground = Color("IconAdviceFg")
        let iconSeverityBackground = Color("IconSeverityBg")
        let iconAreaBackground = Color("IconAreaBg")

        // MARK: Confidence bar (halaman detail prediksi)

        /// Segmen tengah bar keyakinan — `#ffcc00` (Accents/Yellow Figma).
        let confidenceMid = Color("ConfidenceMid")
        /// Balon nilai keyakinan — `#01796d`.
        let tooltip = Color("TooltipTeal")

        // MARK: Pemisah

        let separator = Color(uiColor: .separator)
    }
}

// MARK: - Gradient

extension Theme {
    static let gradient = Gradients()

    struct Gradients {
        /// Tombol utama di Figma: capsule tinggi 48, radius 32, gradient
        /// horizontal. Dipakai `PillButtonStyle`.
        var primaryButton: LinearGradient {
            LinearGradient(
                colors: [Theme.color.brandGradientStart, Theme.color.brandGradientEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        /// Header Home/Detail rumah.
        var home: LinearGradient {
            LinearGradient(
                colors: [Theme.color.homeGradientTop, Theme.color.homeGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        /// Peredup di atas foto latar layar guidance, biar teks putih tetap
        /// kebaca. Figma bikin ini dengan naruh foto gelap di atas kanvas hitam;
        /// di sini dijadiin overlay eksplisit supaya kekuatannya bisa diatur
        /// tanpa nyentuh asetnya.
        var guidanceScrim: LinearGradient {
            // Berhenti di HITAM PENUH di 12% terakhir. Itu bikin area tombol di
            // bawah bisa dikasih hitam solid tanpa keliatan sambungannya —
            // sebelumnya scrim-nya cuma sampai 65%, jadi strip hitam di bawah
            // tombol selalu kelihatan sebagai pita yang beda.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .black.opacity(0.35), location: 0.35),
                    .init(color: .black.opacity(0.70), location: 0.80),
                    .init(color: .black, location: 0.88),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Ukuran

extension Theme {
    /// Angka layout yang muncul berulang di Figma. Yang cocok sama metrik
    /// standar iOS (misal padding tepi 16pt) sengaja NGGAK ditaruh di sini —
    /// biarin container sistem yang ngasih, jangan ditulis ulang.
    enum Metric {
        /// Padding kiri-kanan konten layar guidance (Figma: 40pt).
        static let guidanceHorizontalPadding: CGFloat = 40
        /// Tinggi tombol utama (Figma: 48pt).
        static let buttonHeight: CGFloat = 48
        /// Radius tombol utama (Figma: 32pt — capsule, karena > setengah tinggi).
        static let buttonCornerRadius: CGFloat = 32
        /// Radius kartu contoh jamur/lembap (Figma: 5pt).
        static let sampleCardCornerRadius: CGFloat = 5
        /// Radius kartu umum di layar Home/Report.
        static let cardCornerRadius: CGFloat = 18
    }
}

extension LinearGradient {
    /// Alias lama — dipertahankan biar view yang udah ada nggak perlu diubah
    /// sekaligus. Pakai `Theme.gradient.home` buat kode baru.
    static var hoomoldHome: LinearGradient { Theme.gradient.home }
}
