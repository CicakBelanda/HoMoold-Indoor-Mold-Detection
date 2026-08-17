//
//  RoomTypeSelectionView.swift
//  HoMoold
//

import SwiftUI

struct RoomTypeSelectionView: View {
    @ObservedObject var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Which room do you want to inspect?")
                    .font(.title2.weight(.bold))
                    .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(RoomType.allCases) { type in
                        Button {
                            flow.roomType = type
                            flow.path.append(.capture)
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
        .navigationTitle(flow.existingProperty.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

#Preview {
    let property = KosProperty(name: "Sample Property", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        RoomTypeSelectionView(flow: InspectionFlowState(existingProperty: property))
    }
}
