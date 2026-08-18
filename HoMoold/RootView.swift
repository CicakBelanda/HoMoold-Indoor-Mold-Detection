//
//  RootView.swift
//  HoMoold
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var store = AppDataStore()

    var body: some View {
        HomeListView(store: store)
            // fullScreenCover, bukan sheet: kartu mint bersudut-atas-membulat di
            // OnboardingView itu bagian desainnya. Sheet bakal nambah sudut
            // sendiri + nge-dim Home di belakang, jadi dobel.
            .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { _ in })) {
                OnboardingView()
            }
    }
}

#Preview {
    RootView()
}
