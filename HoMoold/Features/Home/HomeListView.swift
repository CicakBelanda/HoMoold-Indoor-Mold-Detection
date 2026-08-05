//
//  HomeListView.swift
//  HoMoold
//

import SwiftUI

struct HomeListView: View {
    private let store: AppDataStore
    @StateObject private var viewModel: HomeListViewModel
    @State private var path = NavigationPath()
    @State private var showNewInspection = false
    @State private var showFriendDemo = false

    init(store: AppDataStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if viewModel.properties.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.properties) { property in
                            NavigationLink(value: property.id) {
                                PropertyCard(property: property)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Kos Kamu")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { propertyID in
                PropertyDetailView(store: store, propertyID: propertyID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFriendDemo = true
                    } label: {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("Y")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .accessibilityLabel("Profil dan tampilan awal proyek")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showNewInspection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                }
                .accessibilityLabel("Mulai pemeriksaan baru")
                .padding(20)
            }
        }
        .fullScreenCover(isPresented: $showNewInspection) {
            InspectionFlowView(store: store)
        }
        .onChange(of: store.lastSavedPropertyID) { _, newValue in
            guard let newValue else { return }
            path = NavigationPath()
            path.append(newValue)
            store.lastSavedPropertyID = nil
        }
        .sheet(isPresented: $showFriendDemo) {
            NavigationStack {
                ContentView()
                    .navigationTitle("Original Template")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Tutup") { showFriendDemo = false }
                        }
                    }
                    .safeAreaInset(edge: .top) {
                        Text("Tampilan awal project dari Kevin — disimpan di sini, bukan dihapus.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 6)
                    }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "house")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Belum ada kos yang diperiksa")
                .font(.headline)
            Text("Tap tombol + untuk mulai pemeriksaan pertamamu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 120)
        .padding(.horizontal, 32)
    }
}

#Preview {
    HomeListView(store: AppDataStore())
}
