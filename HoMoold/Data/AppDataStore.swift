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

    @discardableResult
    func addInspection(_ inspection: RoomInspection, toPropertyNamed name: String, location: String) -> UUID {
        if let index = properties.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            properties[index].rooms.append(inspection)
            return properties[index].id
        } else {
            let newProperty = KosProperty(name: name, location: location, thumbnail: inspection.thumbnail, rooms: [inspection])
            properties.append(newProperty)
            return newProperty.id
        }
    }

    func toggleReviewed(findingID: UUID, inRoom roomID: UUID, ofProperty propertyID: UUID) {
        guard let pIndex = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        guard let rIndex = properties[pIndex].rooms.firstIndex(where: { $0.id == roomID }) else { return }
        guard let fIndex = properties[pIndex].rooms[rIndex].findings.firstIndex(where: { $0.id == findingID }) else { return }
        properties[pIndex].rooms[rIndex].findings[fIndex].isReviewed.toggle()
    }
}
