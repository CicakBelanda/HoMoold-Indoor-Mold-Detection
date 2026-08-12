//
//  AppDataStore.swift
//  HoMoold
//
//  Sumber data in-memory untuk seluruh app (Non-Goal: tidak ada backend/API).
//  Mulai kosong — semua KosProperty dibuat dari hasil inspeksi asli lewat
//  InspectionFlowView, bukan data dummy.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDataStore: ObservableObject {
    @Published var properties: [KosProperty]
    /// Diset setelah inspeksi baru disimpan, supaya Home bisa langsung membuka
    /// halaman detail rumah yang bersangkutan.
    @Published var lastSavedPropertyID: UUID?

    init(properties: [KosProperty] = []) {
        self.properties = properties
    }

    /// Tambah inspeksi ke rumah yang sudah ada. `location` ditulis ulang ke
    /// properti-nya juga — no-op kalau rumahnya sudah punya lokasi (ConditionFormView
    /// cuma isi field ini kalau propertinya belum punya lokasi sama sekali).
    func attachInspection(_ inspection: RoomInspection, toExistingPropertyID propertyID: UUID, location: KosLocation) {
        guard let index = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        properties[index].rooms.append(inspection)
        properties[index].location = location
    }

    /// Buat entri rumah baru — cuma nama (sesuai sheet "Simpan Rumah" dari FAB
    /// Home). Lokasi & ruangan nyusul belakangan lewat "Tambah Ruangan".
    @discardableResult
    func createProperty(name: String) -> UUID {
        let newProperty = KosProperty(name: name, location: KosLocation(region: "", city: "", district: ""), price: nil, rooms: [])
        properties.append(newProperty)
        return newProperty.id
    }

    func toggleReviewed(findingID: UUID, inRoom roomID: UUID, ofProperty propertyID: UUID) {
        guard let pIndex = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        guard let rIndex = properties[pIndex].rooms.firstIndex(where: { $0.id == roomID }) else { return }
        guard let fIndex = properties[pIndex].rooms[rIndex].findings.firstIndex(where: { $0.id == findingID }) else { return }
        properties[pIndex].rooms[rIndex].findings[fIndex].isReviewed.toggle()
    }

    func deleteProperty(id: UUID) {
        properties.removeAll { $0.id == id }
    }

    func deleteRoom(roomID: UUID, fromProperty propertyID: UUID) {
        guard let index = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        properties[index].rooms.removeAll { $0.id == roomID }
    }

    /// Ubah kondisi ruangan yang udah tersimpan (lewat EditRoomConditionSheet
    /// di halaman detail rumah) — gak ngubah findings/riskScore, cuma
    /// checklist AC/Jendela/Lembap/Retak Dinding.
    func updateRoomCondition(
        roomID: UUID, ofProperty propertyID: UUID,
        hasAC: Bool, hasWindow: Bool, dampness: Bool, wallCrack: Bool
    ) {
        guard let pIndex = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        guard let rIndex = properties[pIndex].rooms.firstIndex(where: { $0.id == roomID }) else { return }
        properties[pIndex].rooms[rIndex].hasAC = hasAC
        properties[pIndex].rooms[rIndex].hasWindow = hasWindow
        properties[pIndex].rooms[rIndex].dampness = dampness
        properties[pIndex].rooms[rIndex].wallCrack = wallCrack
    }

    func renameProperty(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = properties.firstIndex(where: { $0.id == id }) else { return }
        properties[index].name = trimmed
    }
}
