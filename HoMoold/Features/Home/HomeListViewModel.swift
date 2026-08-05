//
//  HomeListViewModel.swift
//  HoMoold
//

import Combine
import Foundation

@MainActor
final class HomeListViewModel: ObservableObject {
    private let store: AppDataStore

    init(store: AppDataStore) {
        self.store = store
    }

    var properties: [KosProperty] {
        store.properties.sorted { $0.lastInspectionDate > $1.lastInspectionDate }
    }
}
