//
//  MoldRiskInfoSheet.swift
//  HoMoold
//

import SwiftUI

struct MoldRiskInfoSheet: View {
    let explanation: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(20)
            }
            .navigationTitle("Mold Grow Risk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

#Preview {
    MoldRiskInfoSheet(explanation: "Example explanation of the mold risk score methodology.")
}
