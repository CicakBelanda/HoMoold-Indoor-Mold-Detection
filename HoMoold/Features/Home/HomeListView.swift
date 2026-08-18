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

    @MainActor
    init(store: AppDataStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeListViewModel(store: store))
    }

    private var filteredProperties: [KosProperty] {
        viewModel.properties
            .filtered(bySearchText: searchText)
            .sorted(by: sortOrder)
    }

    // Body-nya sengaja DIPECAH jadi beberapa properti kecil, bukan satu rantai
    // panjang. Waktu semuanya numpuk di satu ekspresi, Swift nyerah dengan
    // "unable to type-check this expression in reasonable time" — SwiftUI
    // ngebangun satu tipe generik raksasa dari tiap modifier yang dirantai, dan
    // biayanya naik jauh lebih cepat daripada jumlah barisnya. Kalau nambah
    // sesuatu di sini dan compiler-nya mulai lemot, pecah lagi.
    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Theme.gradient.home.ignoresSafeArea())
                .navigationTitle("Mold Inspection")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search house name")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { sortMenu }
                }
                .navigationDestination(for: UUID.self) { propertyID in
                    PropertyDetailView(store: store, propertyID: propertyID, path: $path)
                }
                .navigationDestination(for: RoomNavigationTarget.self) { target in
                    ReportView(store: store, propertyID: target.propertyID, roomID: target.roomID)
                }
                .overlay(alignment: .bottomTrailing) { addHouseButton }
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
        }
        // Dua modal isi-nama ditempel DI LUAR NavigationStack. Dua-duanya nggak
        // pernah kebuka barengan, jadi aman berbagi `houseNameInput`.
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
                let name = houseNameInput.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, let id = propertyPendingRename?.id {
                    store.renameProperty(id: id, to: name)
                }
                propertyPendingRename = nil
            }
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

    @ViewBuilder
    private var content: some View {
        if viewModel.properties.isEmpty {
            emptyState
        } else {
            List {
                if filteredProperties.isEmpty {
                    noResultsRow
                }

                ForEach(filteredProperties) { property in
                    propertyRow(property)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func propertyRow(_ property: KosProperty) -> some View {
        Button {
            path.append(property.id)
        } label: {
            PropertyCard(property: property)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        // Tint merahnya ditulis DI TOMBOL — `.tint(.primary)` di bawah (buat
        // context menu) kalau nggak ditimpa bikin tombol Delete-nya kegambar
        // hitam, bukan merah.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                propertyPendingDelete = property
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Theme.color.riskHigh)
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

    /// `.glassProminent` — tombol aksi utama ala Liquid Glass: kacanya ketarik
    /// warna accent (HoomoldTeal), bukan kaca netral kayak `.glass` yang dipakai
    /// kontrol chrome di layar kamera.
    private var addHouseButton: some View {
        Button {
            showSaveHouse = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .accessibilityLabel("Start a new inspection")
        .padding(20)
    }

    /// Menu urutan doang — saringan risiko udah pindah ke halaman detail rumah.
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

    /// Figma 1339:7229 — teks doang, rata tengah vertikal, TANPA ikon. Sengaja
    /// nggak pakai `ContentUnavailableView`: bawaannya selalu naruh ikon gede di
    /// atas judul, dan desainnya nggak ada ikonnya.
    private var emptyState: some View {
        centeredMessage(
            title: "No Entries",
            message: "To add an entry, tap the plus button."
        )
    }

    /// Baris "kosong" DI DALAM list, bukan layar penuh — kolom pencariannya harus
    /// tetap kelihatan di atasnya biar user bisa langsung ganti kata kuncinya.
    private var noResultsRow: some View {
        VStack(spacing: 2) {
            Text("No Results")
                .font(Theme.font.title2Emphasized)
                .foregroundStyle(Theme.color.textPrimary)

            Text("Try a different house name or location.")
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
