//
//  RootView.swift
//  HoMoold
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var store = AppDataStore()

    var body: some View {
        Group {
            if hasSeenOnboarding {
                HomeListView(store: store)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasSeenOnboarding)
    }
}

#Preview {
    RootView()
}
