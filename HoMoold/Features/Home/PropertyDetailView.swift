//
//  PropertyDetailView.swift
//  HoMoold
//

import SwiftUI

struct PropertyDetailView: View {
    @StateObject private var viewModel: PropertyDetailViewModel
    @ObservedObject private var store: AppDataStore
    @Binding private var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    @State private var showAddInspection = false
    @State private var roomPendingDelete: RoomInspection?
    @State private var showDeletePropertyConfirm = false
    @State private var showRenameAlert = false
    @State private var renameText = ""

    init(store: AppDataStore, propertyID: UUID, path: Binding<NavigationPath>) {
        self.store = store
        self._path = path
        _viewModel = StateObject(wrappedValue: PropertyDetailViewModel(store: store, propertyID: propertyID))
    }

    var body: some View {
        List {
            if let priceText = viewModel.property?.priceText {
                Text(priceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Button {
                showAddInspection = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Tambah Ruangan")
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tambah ruangan yang diperiksa di kos ini")
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))

            ForEach(viewModel.rooms) { room in
                if let property = viewModel.property {
                    Button {
                        path.append(RoomNavigationTarget(propertyID: property.id, roomID: room.id))
                    } label: {
                        RoomInspectionCard(room: room)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            roomPendingDelete = room
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(viewModel.property?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameText = viewModel.property?.name ?? ""
                        showRenameAlert = true
                    } label: {
                        Label("Ubah Nama Kos", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeletePropertyConfirm = true
                    } label: {
                        Label("Hapus Kos", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Opsi kos")
            }
        }
        .fullScreenCover(isPresented: $showAddInspection) {
            if let property = viewModel.property {
                InspectionFlowView(store: store, existingProperty: property)
            }
        }
        .alert(
            "Hapus Ruangan",
            isPresented: Binding(
                get: { roomPendingDelete != nil },
                set: { if !$0 { roomPendingDelete = nil } }
            )
        ) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                if let roomID = roomPendingDelete?.id, let propertyID = viewModel.property?.id {
                    store.deleteRoom(roomID: roomID, fromProperty: propertyID)
                }
                roomPendingDelete = nil
            }
        } message: {
            Text("Hasil pemeriksaan ruangan ini akan dihapus. Tindakan ini tidak bisa dibatalkan.")
        }
        .alert("Hapus Kos", isPresented: $showDeletePropertyConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                if let id = viewModel.property?.id {
                    store.deleteProperty(id: id)
                }
                dismiss()
            }
        } message: {
            Text("Semua data pemeriksaan di \"\(viewModel.property?.name ?? "")\" akan ikut terhapus. Tindakan ini tidak bisa dibatalkan.")
        }
        .alert("Ubah Nama Kos", isPresented: $showRenameAlert) {
            TextField("Nama kos", text: $renameText)
            Button("Batal", role: .cancel) {}
            Button("Simpan") {
                if let id = viewModel.property?.id {
                    store.renameProperty(id: id, to: renameText)
                }
            }
        }
    }
}

/// Sengaja beda layout dari PropertyCard di Home — foto besar di atas (dengan
/// badge risiko & kotak temuan overlay langsung di foto), baru info di bawah.
private struct RoomInspectionCard: View {
    let room: RoomInspection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: room.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 190)
                    .clipped()
                    .accessibilityHidden(true)

                if let topFinding = room.findings.first {
                    BoundingBoxOverlay(findingClass: topFinding.findingClass, boundingBox: topFinding.boundingBox)
                        .frame(height: 190)
                }

                RiskBadge(level: room.riskLevel)
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(room.roomType.rawValue, systemImage: room.roomType.iconName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Detected Mold")
                    .font(.headline)

                Text(room.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(14)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    let store = AppDataStore()
    return NavigationStack {
        PropertyDetailView(store: store, propertyID: store.properties[0].id, path: .constant(NavigationPath()))
    }
}
