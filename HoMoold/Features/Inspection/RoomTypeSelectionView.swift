//
//  RoomTypeSelectionView.swift
//  HoMoold
//

import SwiftUI

struct RoomTypeSelectionView: View {
    @ObservedObject var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Ruangan apa yang mau diperiksa?")
                    .font(.title2.weight(.bold))
                    .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(RoomType.allCases) { type in
                        Button {
                            flow.roomType = type
                            flow.path.append(.record)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: type.iconName)
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.accentColor)
                                Text(type.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(flow.existingProperty?.name ?? "Tipe Ruangan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Batal") { dismiss() }
            }
        }
        .task {
            // Kos baru: ambil lokasi otomatis diam-diam di background, dipakai nanti
            // pas NewReportInfoView beneran menyimpan. Kos yang sudah ada tidak perlu.
            guard flow.existingProperty == nil else { return }
            if let name = await locationService.fetchCurrentLocationName() {
                flow.autoDetectedLocation = name
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoomTypeSelectionView(flow: InspectionFlowState(existingProperty: nil))
    }
}
