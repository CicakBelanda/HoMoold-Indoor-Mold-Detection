//
//  InfoSheetButton.swift
//  HoMoold
//

import SwiftUI

/// Ikon (i) kecil yang membuka bottom sheet penjelasan saat ditap.
struct InfoSheetButton<SheetContent: View>: View {
    let accessibilityLabel: String
    @ViewBuilder let sheetContent: () -> SheetContent

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
        .sheet(isPresented: $isPresented) {
            sheetContent()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
