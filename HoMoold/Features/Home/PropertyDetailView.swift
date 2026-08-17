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
    @State private var roomPendingRename: RoomInspection?
    @State private var roomNameInput = ""
    @State private var showDeletePropertyConfirm = false
    @State private var showRenameAlert = false
    @State private var renameText = ""

    @MainActor
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
                    Text("Add new Room")
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
            .accessibilityLabel("Add a room to inspect in this house")
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
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            roomNameInput = room.name
                            roomPendingRename = room
                        } label: {
                            Label("Rename Room", systemImage: "pencil")
                        }
                        Button {
                            roomPendingEdit = room
                        } label: {
                            Label("Edit Condition", systemImage: "checklist")
                        }
                        Button(role: .destructive) {
                            roomPendingDelete = room
                        } label: {
                            Label("Delete Room", systemImage: "trash")
                        }
                    }
                    .tint(.primary)
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
                        Label("Rename House", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeletePropertyConfirm = true
                    } label: {
                        Label("Delete House", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                // Kontrol chrome — warna label bawaan, bukan brand.
                .tint(.primary)
                .accessibilityLabel("House options")
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
            "Delete Room",
            isPresented: Binding(
                get: { roomPendingDelete != nil },
                set: { if !$0 { roomPendingDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let roomID = roomPendingDelete?.id, let propertyID = viewModel.property?.id {
                    store.deleteRoom(roomID: roomID, fromProperty: propertyID)
                }
                roomPendingDelete = nil
            }
        } message: {
            Text("This room's inspection result will be deleted. This can't be undone.")
        }
        .alert("Delete House", isPresented: $showDeletePropertyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = viewModel.property?.id {
                    store.deleteProperty(id: id)
                }
                dismiss()
            }
        } message: {
            Text("All inspection data in \"\(viewModel.property?.name ?? "")\" will be deleted too. This can't be undone.")
        }
        // Alert bawaan, sama kayak rename rumah — konsisten dan HIG.
        .alert(
            "Rename Room",
            isPresented: Binding(
                get: { roomPendingRename != nil },
                set: { if !$0 { roomPendingRename = nil } }
            )
        ) {
            TextField("Room name", text: $roomNameInput)
            Button("Cancel", role: .cancel) { roomPendingRename = nil }
            Button("Save") {
                if let roomID = roomPendingRename?.id, let propertyID = viewModel.property?.id {
                    store.renameRoom(roomID: roomID, ofProperty: propertyID, to: roomNameInput)
                }
                roomPendingRename = nil
            }
        }
        .alert("Rename House", isPresented: $showRenameAlert) {
            TextField("House name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, let id = viewModel.property?.id else { return }
                store.renameProperty(id: id, to: name)
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
                if room.hasMold {
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
                } else {
                    noMoldPlaceholder
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    // Nama DAN tipe — kartu ruangan di Figma nampilin dua-duanya,
                    // dan tipe doang nggak cukup buat mbedain dua kamar tidur.
                    // Nama DAN tipe, SELALU dua-duanya. Sebelumnya tipe-nya
                    // disembunyiin kalau kebetulan sama persis dengan namanya
                    // (kejadian pas user nggak ngisi nama, karena nama-nya
                    // jatuh ke nama tipe) — tapi itu bikin barisnya kadang ada
                    // kadang nggak, dan kartunya jadi nggak konsisten.
                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.name)
                            .font(Theme.font.subheadlineMedium)
                            .foregroundStyle(Theme.color.textPrimary)
                            .lineLimit(1)

                        Text(room.roomType.rawValue)
                            .font(Theme.font.caption)
                            .foregroundStyle(Theme.color.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(relativeDate(room.date))
                        .font(.caption2)
                        .foregroundStyle(Theme.color.textSecondary)
                }

                conditionChips

                Spacer(minLength: 0)

                moldGrowRateBadge
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    /// Grafis "no mold" buat ruangan yang nggak ada temuannya (Figma 1339:6825,
    /// kartu ketiga).
    ///
    /// Pakai `.fit` di atas latar putih, BUKAN `.fill` kayak foto biasa —
    /// gambarnya persegi dan ada tulisan "no mold" di bawahnya, jadi kalau
    /// di-fill ke slot potret 132x166 tulisannya kepotong.
    private var noMoldPlaceholder: some View {
        Image("NoMoldPlaceholder")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(8)
            .frame(width: 132, height: 166)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.black.opacity(0.12))
            )
            .accessibilityHidden(true)
    }

    /// Empat kondisi jadi chip, bukan empat baris label+ikon.
    ///
    /// Versi baris itu makan tinggi kartu paling banyak padahal isinya cuma
    /// ya/tidak. Sebagai chip, yang ADA langsung kelihatan karena berwarna, dan
    /// yang nggak ada tetap kebaca tapi mundur ke belakang.
    private var conditionChips: some View {
        let items = room.detectionChecklist
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(spacing: 6) {
                    ForEach(items[start..<min(start + 2, items.count)]) { item in
                        conditionChip(item)
                    }
                }
            }
        }
    }

    private func conditionChip(_ item: DetectionItem) -> some View {
        HStack(spacing: 3) {
            Image(systemName: item.isPresent ? "checkmark" : "xmark")
                .font(.system(size: 8, weight: .bold))

            Text(item.label)
                .font(.caption2)
                // Kolom kanan cuma ~196pt, dan "Dampness" + "Wall Crack" dalam
                // satu baris pas-pasan. Dikunci satu baris + boleh mengecil
                // dikit supaya nggak pernah kepotong jadi "Wall Cra…".
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(item.isPresent ? Theme.color.brand : Theme.color.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            (item.isPresent ? Theme.color.brand : Theme.color.textSecondary).opacity(0.12),
            in: Capsule()
        )
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "d MMM"
            : "d MMM yyyy"
        return formatter.string(from: date)
    }

    private var accessibilityDescription: String {
        let spots = room.findings.isEmpty
            ? "no mold spots"
            : "\(room.findings.count) mold spot\(room.findings.count == 1 ? "" : "s")"
        return "\(room.name), \(room.roomType.rawValue), \(spots), \(room.riskLevel.pillLabel)"
    }

    /// Label abu di atas, pil warna selebar kartu di bawah — sesuai desain.
    /// Sebelumnya cuma badge hitam kecil, dan warnanya (yang justru info
    /// utamanya) nyaris nggak kelihatan.
    private var moldGrowRateBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mold Growth Rate")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)

            Text(room.riskLevel.pillLabel)
                .font(Theme.font.caption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    room.riskLevel.color,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
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
