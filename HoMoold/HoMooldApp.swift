//
//  HoMooldApp.swift
//  HoMoold
//
//  Created by Kevin Joseph Handoyo on 03/08/26.
//

import SwiftUI

@main
struct HoMooldApp: App {
    init() {
        Self.applyUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Cuma satu mode desain (light) buat sekarang — dark mode belum
                // di-support, dan beberapa layar (guidance) sengaja gelap sendiri.
                .preferredColorScheme(.light)
                // Tint eksplisit buat seluruh hierarki SwiftUI. AccentColor di
                // asset catalog aja NGGAK cukup — lihat catatan di
                // applyNavigationBarAppearance.
                .tint(Theme.color.brand)
        }
    }

    /// Dua hal yang cuma bisa diatur lewat UIKit:
    ///
    /// 1. **Tint window.** `.tint()` di atas ngurus hierarki SwiftUI, tapi yang
    ///    dipresentasiin UIKit di baliknya — `.alert` (UIAlertController), tombol
    ///    Cancel di `.searchable` — ngambil tint dari WINDOW, bukan dari
    ///    AccentColor di asset catalog. Tanpa baris ini tombol-tombol itu biru
    ///    bawaan Apple walaupun AccentColor-nya udah teal.
    ///
    /// 2. **Warna judul navigasi.** Di Figma judulnya teal tua, dan SwiftUI nggak
    ///    punya API buat ngewarnain large title. Sengaja NGGAK bikin judul palsu
    ///    pakai Text di dalam ScrollView — cara itu ngilangin animasi collapse
    ///    large-title, back-swipe, dan perilaku safe-area dari NavigationStack.
    private static func applyUIKitAppearance() {
        let brand = UIColor(named: "HoomoldTeal") ?? .systemTeal
        let brandDark = UIColor(named: "HoomoldDarkTeal") ?? .label

        UIWindow.appearance().tintColor = brand

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: brandDark]
        appearance.titleTextAttributes = [.foregroundColor: brandDark]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
