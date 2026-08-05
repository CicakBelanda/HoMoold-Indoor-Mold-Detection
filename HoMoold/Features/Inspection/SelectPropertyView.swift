//
//  SelectPropertyView.swift
//  HoMoold
//

import SwiftUI

/// Langkah pertama flow inspeksi baru: pilih kos yang sudah ada atau catat kos baru,
/// supaya hasil inspeksi tahu mau disimpan ke properti mana.
struct SelectPropertyView: View {
    let store: AppDataStore
    @ObservedObject var flow: InspectionFlowState

    @State private var mode: Mode = .existing
    @State private var newName = ""
    @State private var newLocation = ""
    @State private var selectedExistingID: UUID?
    @StateObject private var locationService = LocationService()

    private enum Mode: String, CaseIterable {
        case existing = "Kos yang sudah ada"
        case new = "Kos baru"
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            switch mode {
            case .existing:
                Section("Pilih kos") {
                    if store.properties.isEmpty {
                        Text("Belum ada kos tersimpan. Pakai tab \"Kos baru\".")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.properties) { property in
                            Button {
                                selectedExistingID = property.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(property.name).foregroundStyle(.primary)
                                        Text(property.location).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedExistingID == property.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            case .new:
                Section("Detail kos") {
                    TextField("Nama kos, mis. Kos Melati", text: $newName)
                    HStack {
                        TextField("Lokasi (kecamatan), mis. Kec. Cisauk", text: $newLocation)
                        if locationService.isFetching {
                            ProgressView()
                        } else {
                            Button {
                                Task {
                                    if let name = await locationService.fetchCurrentLocationName() {
                                        newLocation = name
                                    }
                                }
                            } label: {
                                Image(systemName: "location.fill")
                            }
                            .accessibilityLabel("Gunakan lokasi saat ini")
                        }
                    }
                    if let error = locationService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Ruangan Mana yang Diperiksa")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Lanjut") {
                switch mode {
                case .existing:
                    if let id = selectedExistingID, let property = store.properties.first(where: { $0.id == id }) {
                        flow.propertyName = property.name
                        flow.propertyLocation = property.location
                    }
                case .new:
                    flow.propertyName = newName.trimmingCharacters(in: .whitespaces)
                    flow.propertyLocation = newLocation.trimmingCharacters(in: .whitespaces)
                }
                flow.path.append(.roomType)
            }
            .buttonStyle(.pillProminent)
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(.bar)
        }
    }

    private var canContinue: Bool {
        switch mode {
        case .existing:
            return selectedExistingID != nil
        case .new:
            return !newName.trimmingCharacters(in: .whitespaces).isEmpty
                && !newLocation.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

#Preview {
    NavigationStack {
        SelectPropertyView(store: AppDataStore(), flow: InspectionFlowState())
    }
}
