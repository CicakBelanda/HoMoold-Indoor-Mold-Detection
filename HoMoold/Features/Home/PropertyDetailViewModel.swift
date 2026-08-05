//
//  PropertyDetailViewModel.swift
//  HoMoold
//

import Combine
import Foundation

@MainActor
final class PropertyDetailViewModel: ObservableObject {
    private let store: AppDataStore
    let propertyID: UUID

    init(store: AppDataStore, propertyID: UUID) {
        self.store = store
        self.propertyID = propertyID
    }

    var property: KosProperty? {
        store.properties.first { $0.id == propertyID }
    }

    var rooms: [RoomInspection] {
        (property?.rooms ?? []).sorted { $0.date > $1.date }
    }
}
