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
    @State private var roomPendingEdit: RoomInspection?
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
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tambah ruangan yang diperiksa di rumah ini")
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
                    .contextMenu {
                        Button {
                            roomPendingEdit = room
                        } label: {
                            Label("Ubah Kondisi", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomPendingDelete = room
                        } label: {
                            Label("Hapus Ruangan", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(LinearGradient.hoomoldHome.ignoresSafeArea())
        .navigationTitle(viewModel.property?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameText = viewModel.property?.name ?? ""
                        showRenameAlert = true
                    } label: {
                        Label("Ubah Nama Rumah", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeletePropertyConfirm = true
                    } label: {
                        Label("Hapus Rumah", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Opsi rumah")
            }
        }
        .fullScreenCover(isPresented: $showAddInspection) {
            if let property = viewModel.property {
                InspectionFlowView(store: store, existingProperty: property)
            }
        }
        .sheet(item: $roomPendingEdit) { room in
            EditRoomConditionSheet(room: room) { hasAC, hasWindow, dampness, wallCrack in
                if let propertyID = viewModel.property?.id {
                    store.updateRoomCondition(
                        roomID: room.id, ofProperty: propertyID,
                        hasAC: hasAC, hasWindow: hasWindow, dampness: dampness, wallCrack: wallCrack
                    )
                }
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
        .alert("Hapus Rumah", isPresented: $showDeletePropertyConfirm) {
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
        .alert("Ubah Nama Rumah", isPresented: $showRenameAlert) {
            TextField("Nama rumah", text: $renameText)
            Button("Batal", role: .cancel) {}
            Button("Simpan") {
                if let id = viewModel.property?.id {
                    store.renameProperty(id: id, to: renameText)
                }
            }
        }
    }
}

/// Thumbnail di kiri + checklist kondisi & badge Mold Grow Rate di kanan.
private struct RoomInspectionCard: View {
    let room: RoomInspection

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: room.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 132, height: 166)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.black.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                if let topFinding = room.findings.first {
                    BoundingBoxOverlay(findingClass: topFinding.findingClass, boundingBox: topFinding.boundingBox)
                        .frame(width: 132, height: 166)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(room.roomType.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(relativeDate(room.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(room.detectionChecklist) { item in
                        HStack {
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Image(systemName: item.isPresent ? "checkmark.square" : "xmark.square")
                                .font(.caption)
                                .foregroundStyle(item.isPresent ? .secondary : Color.secondary.opacity(0.4))
                        }
                    }
                }

                Spacer(minLength: 0)

                moldGrowRateBadge
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Hari ini" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private var moldGrowRateBadge: some View {
        HStack(spacing: 6) {
            Text("Mold Grow Rate")
                .font(.caption2)
                .foregroundStyle(.white)
            Text(room.riskLevel.labelID)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
            SignalBars(level: room.riskLevel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Mini bar-chart 3-batang (rendah/sedang/tinggi) yang nunjukin RiskLevel —
/// dipakai di badge "Mold Grow Rate".
private struct SignalBars: View {
    let level: RiskLevel

    private var activeBars: Int {
        switch level {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(index < activeBars ? 1 : 0.35))
                    .frame(width: 3, height: 6 + CGFloat(index) * 4)
            }
        }
    }
}

#Preview {
    let room = RoomInspection(
        roomType: .bedroom, riskLevel: .high, riskScore: 82, findings: [],
        hasAC: false, hasWindow: true, dampness: true, wallCrack: true, date: Date()
    )
    let property = KosProperty(
        name: "Kos Contoh", location: HomeLocation(region: "Banten", city: "Tangerang", district: "Kec. Cisauk"),
        price: 850_000, rooms: [room]
    )
    let store = AppDataStore(properties: [property])
    return NavigationStack {
        PropertyDetailView(store: store, propertyID: property.id, path: .constant(NavigationPath()))
    }
}
