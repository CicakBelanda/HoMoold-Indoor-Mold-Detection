//
//  HoMooldApp.swift
//  HoMoold
//
//  Created by Kevin Joseph Handoyo on 03/08/26.
//

import SwiftUI

@main
struct HoMooldApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Cuma satu mode desain (light) buat sekarang — dark mode belum di-support.
                .preferredColorScheme(.light)
        }
    }
}
