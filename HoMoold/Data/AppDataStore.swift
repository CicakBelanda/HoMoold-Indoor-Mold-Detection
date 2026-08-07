//
//  AppDataStore.swift
//  HoMoold
//
//  Sumber data in-memory untuk seluruh app (Non-Goal: tidak ada backend/API).
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDataStore: ObservableObject {
    @Published var properties: [KosProperty]
    /// Diset setelah inspeksi baru disimpan, supaya Home bisa langsung membuka
    /// halaman detail kos yang bersangkutan.
    @Published var lastSavedPropertyID: UUID?

    init(properties: [KosProperty] = DummyDataFactory.seedProperties()) {
        self.properties = properties
    }

    /// Tambah inspeksi ke kos yang sudah ada (dipakai dari halaman detail kos —
    /// nama/lokasinya sudah diketahui, jadi tidak perlu tanya lagi).
    @discardableResult
    func attachInspection(_ inspection: RoomInspection, toExistingPropertyID propertyID: UUID) -> UUID {
        guard let index = properties.firstIndex(where: { $0.id == propertyID }) else { return propertyID }
        properties[index].rooms.append(inspection)
        return propertyID
    }

    /// Buat entri kos baru (dipakai dari flow inspeksi via FAB Home — nama & harga
    /// baru diisi di halaman "New Report" setelah hasil analisis kelihatan).
    @discardableResult
    func createProperty(name: String, location: String, price: Int?, firstInspection: RoomInspection) -> UUID {
        let newProperty = KosProperty(name: name, location: location, price: price, thumbnail: firstInspection.thumbnail, rooms: [firstInspection])
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

    func renameProperty(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = properties.firstIndex(where: { $0.id == id }) else { return }
        properties[index].name = trimmed
    }
}
