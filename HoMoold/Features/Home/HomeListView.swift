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
    /// Dipakai bareng alert "Add New House" dan "Rename House" — dua-duanya
    /// nggak pernah kebuka barengan.
    @State private var houseNameInput = ""
    @State private var sortOrder: HomeSortOrder = .recent
    @State private var riskFilter: HomeRiskFilter = .all

    @MainActor
    init(store: AppDataStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeListViewModel(store: store))
    }

    private var filteredProperties: [KosProperty] {
        viewModel.properties
            .filtered(by: riskFilter, searchText: searchText)
            .sorted(by: sortOrder)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.properties.isEmpty {
                    emptyState
                } else {
                    List {
                        // Chip-nya SELALU ada selama masih ada rumah — kalau
                        // cuma ditampilin waktu hasilnya nggak kosong, user yang
                        // nyaring sampai nol nggak punya jalan buat balikin.
                        filterChips

                        if filteredProperties.isEmpty {
                            noResultsRow
                        }

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
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    houseNameInput = property.name
                                    propertyPendingRename = property
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    propertyPendingDelete = property
                                } label: {
                                    Label("Delete House", systemImage: "trash")
                                }
                            }
                            .tint(.primary)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.gradient.home.ignoresSafeArea())
            .navigationTitle("Inspection")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search house name")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
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
                .accessibilityLabel("Start a new inspection")
                .padding(20)
            }
            .alert(
                "Delete House",
                isPresented: Binding(
                    get: { propertyPendingDelete != nil },
                    set: { if !$0 { propertyPendingDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let id = propertyPendingDelete?.id {
                        store.deleteProperty(id: id)
                    }
                    propertyPendingDelete = nil
                }
            } message: {
                Text("All inspection data in \"\(propertyPendingDelete?.name ?? "")\" will be deleted too. This can't be undone.")
            }
            .alert(
                "Rename House",
                isPresented: Binding(
                    get: { propertyPendingRename != nil },
                    set: { if !$0 { propertyPendingRename = nil } }
                )
            ) {
                TextField("House name", text: $houseNameInput)
                Button("Cancel", role: .cancel) { propertyPendingRename = nil }
                Button("Save") {
                    if let id = propertyPendingRename?.id {
                        store.renameProperty(id: id, to: houseNameInput)
                    }
                    propertyPendingRename = nil
                }
            }
        }
        .alert("Add New House", isPresented: $showSaveHouse) {
            TextField("House name", text: $houseNameInput)
            Button("Cancel", role: .cancel) { houseNameInput = "" }
            Button("Save") {
                let name = houseNameInput.trimmingCharacters(in: .whitespaces)
                houseNameInput = ""
                guard !name.isEmpty else { return }
                let id = store.createProperty(name: name)
                path = NavigationPath()
                path.append(id)
            }
        } message: {
            Text("Give this house a name so you can find it later.")
        }
        .onChange(of: showSaveHouse) { _, isShowing in
            if isShowing { houseNameInput = "" }
        }
        .onChange(of: store.lastSavedPropertyID) { _, newValue in
            guard let newValue else { return }
            path = NavigationPath()
            path.append(newValue)
            store.lastSavedPropertyID = nil
        }
    }

    /// Menu urutan doang — saringannya udah pindah ke deretan chip.
    ///
    /// `Picker` di dalam `Menu` bikin iOS ngasih centang di pilihan yang aktif
    /// secara otomatis, sama kayak menu sortir di Files/Mail.
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOrder) {
                ForEach(HomeSortOrder.allCases) { order in
                    Label(order.label, systemImage: order.symbol).tag(order)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .tint(.primary)
        .accessibilityLabel("Sort")
    }

    /// Deretan chip saringan, langsung di bawah judul.
    ///
    /// Lebih kebaca daripada di dalam menu: saringan yang lagi aktif kelihatan
    /// tanpa harus dibuka dulu, dan gantinya cukup satu tap.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeRiskFilter.allCases) { filter in
                    let isSelected = filter == riskFilter

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            riskFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let level = filter.matchingLevel {
                                Circle()
                                    .fill(level.color)
                                    .frame(width: 7, height: 7)
                            }

                            Text(filter.label)
                                .font(Theme.font.subheadline)
                        }
                        .foregroundStyle(isSelected ? Color.white : Theme.color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.color.brand)
                            } else {
                                Capsule().fill(Color.white.opacity(0.7))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        // Chip-nya boleh ngelewatin tepi layar pas di-scroll, tapi list-nya
        // tetap punya inset normal.
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// Figma 1339:7229 — teks doang, rata tengah vertikal, TANPA ikon. Sengaja
    /// nggak pakai `ContentUnavailableView`: bawaannya selalu naruh ikon gede di
    /// atas judul, dan desainnya nggak ada ikonnya.
    private var emptyState: some View {
        centeredMessage(
            title: "No Entries",
            message: "To add an entry, tap the plus button."
        )
    }

    /// Baris "kosong" DI DALAM list, bukan layar penuh — chip saringannya harus
    /// tetap kelihatan di atasnya biar user bisa langsung ganti.
    ///
    /// Pesannya nyesuain: kalau kosongnya karena saringan, bilang gitu; nyuruh
    /// ganti kata kunci padahal masalahnya filter cuma bikin muter-muter.
    private var noResultsRow: some View {
        VStack(spacing: 2) {
            Text("No Results")
                .font(Theme.font.title2Emphasized)
                .foregroundStyle(Theme.color.textPrimary)

            Text(riskFilter == .all
                 ? "Try a different house name or location."
                 : "No houses match the \"\(riskFilter.label)\" filter.")
                .font(Theme.font.subheadline)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 32)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func centeredMessage(title: String, message: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Theme.font.title2Emphasized)
                .foregroundStyle(Theme.color.textPrimary)

            Text(message)
                .font(Theme.font.subheadline)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HomeListView(store: AppDataStore())
}
