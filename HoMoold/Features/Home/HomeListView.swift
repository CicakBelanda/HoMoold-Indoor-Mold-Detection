//
//  HomeListView.swift
//  HoMoold
//

import SwiftUI

struct HomeListView: View {
    @ObservedObject private var store: AppDataStore
    @StateObject private var viewModel: HomeListViewModel
    @State private var path = NavigationPath()
    @State private var showSaveHouse = false
    @State private var searchText = ""
    @State private var propertyPendingDelete: KosProperty?
    @State private var propertyPendingRename: KosProperty?
    @State private var renameText = ""

    init(store: AppDataStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeListViewModel(store: store))
    }

    private var filteredProperties: [KosProperty] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return viewModel.properties }
        return viewModel.properties.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.location.displayText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.properties.isEmpty {
                    emptyState
                } else if filteredProperties.isEmpty {
                    noResultsState
                } else {
                    List {
                        ForEach(filteredProperties) { property in
                            Button {
                                path.append(property.id)
                            } label: {
                                PropertyCard(property: property)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    propertyPendingDelete = property
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    renameText = property.name
                                    propertyPendingRename = property
                                } label: {
                                    Label("Ubah Nama", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    propertyPendingDelete = property
                                } label: {
                                    Label("Hapus Rumah", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LinearGradient.hoomoldHome.ignoresSafeArea())
            .navigationTitle("Rumah Kamu")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Cari nama rumah")
            .navigationDestination(for: UUID.self) { propertyID in
                PropertyDetailView(store: store, propertyID: propertyID, path: $path)
            }
            .navigationDestination(for: RoomNavigationTarget.self) { target in
                ReportView(store: store, propertyID: target.propertyID, roomID: target.roomID)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showSaveHouse = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.extraLarge)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                .accessibilityLabel("Mulai pemeriksaan baru")
                .padding(20)
            }
            .alert(
                "Hapus Rumah",
                isPresented: Binding(
                    get: { propertyPendingDelete != nil },
                    set: { if !$0 { propertyPendingDelete = nil } }
                )
            ) {
                Button("Batal", role: .cancel) {}
                Button("Hapus", role: .destructive) {
                    if let id = propertyPendingDelete?.id {
                        store.deleteProperty(id: id)
                    }
                    propertyPendingDelete = nil
                }
            } message: {
                Text("Semua data pemeriksaan di \"\(propertyPendingDelete?.name ?? "")\" akan ikut terhapus. Tindakan ini tidak bisa dibatalkan.")
            }
            .alert(
                "Ubah Nama Rumah",
                isPresented: Binding(
                    get: { propertyPendingRename != nil },
                    set: { if !$0 { propertyPendingRename = nil } }
                )
            ) {
                TextField("Nama rumah", text: $renameText)
                Button("Batal", role: .cancel) {}
                Button("Simpan") {
                    if let id = propertyPendingRename?.id {
                        store.renameProperty(id: id, to: renameText)
                    }
                    propertyPendingRename = nil
                }
            }
        }
        .sheet(isPresented: $showSaveHouse) {
            SaveHouseSheet { name in
                let id = store.createProperty(name: name)
                path = NavigationPath()
                path.append(id)
            }
        }
        .onChange(of: store.lastSavedPropertyID) { _, newValue in
            guard let newValue else { return }
            path = NavigationPath()
            path.append(newValue)
            store.lastSavedPropertyID = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "house")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Belum ada rumah yang diperiksa")
                .font(.headline)
            Text("Tap tombol + untuk simpan rumah pertamamu, terus tambahin ruangan yang mau diperiksa.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 120)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Gak ketemu rumahnya")
                .font(.headline)
            Text("Coba cari pakai nama atau lokasi lain.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 120)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    HomeListView(store: AppDataStore())
}
