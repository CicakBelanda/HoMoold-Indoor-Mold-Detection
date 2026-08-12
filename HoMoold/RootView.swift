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
            .sheet(isPresented: Binding(get: { !hasSeenOnboarding }, set: { _ in })) {
                OnboardingView()
                    .interactiveDismissDisabled()
            }
    }
}

#Preview {
    RootView()
}
