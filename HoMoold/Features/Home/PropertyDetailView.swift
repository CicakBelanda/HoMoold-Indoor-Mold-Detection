//
//  PropertyDetailView.swift
//  HoMoold
//

import SwiftUI

struct PropertyDetailView: View {
    @StateObject private var viewModel: PropertyDetailViewModel
    private let store: AppDataStore

    init(store: AppDataStore, propertyID: UUID) {
        self.store = store
        _viewModel = StateObject(wrappedValue: PropertyDetailViewModel(store: store, propertyID: propertyID))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.rooms) { room in
                    if let property = viewModel.property {
                        NavigationLink {
                            ReportView(store: store, propertyID: property.id, roomID: room.id)
                        } label: {
                            RoomInspectionCard(room: room)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(viewModel.property?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoomInspectionCard: View {
    let room: RoomInspection

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: room.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                RoomTagRow(roomType: room.roomType, riskLevel: room.riskLevel)

                Text("Detected Mold")
                    .font(.headline)

                Text(room.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    let store = AppDataStore()
    return NavigationStack {
        PropertyDetailView(store: store, propertyID: store.properties[0].id)
    }
    .environmentObject(store)
}
