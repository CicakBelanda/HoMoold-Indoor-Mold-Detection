//
//  InspectionFlowState.swift
//  HoMoold
//

import Combine
import Foundation

enum InspectionStep: Hashable {
    case record
    case preview
    case loading
    case report
    case newReportInfo // cuma dipakai kalau existingProperty == nil (kos baru)
}

@MainActor
final class InspectionFlowState: ObservableObject {
    @Published var path: [InspectionStep] = []
    @Published var roomType: RoomType?
    @Published var recordedVideoURL: URL?
    @Published var resultInspection: RoomInspection?

    /// Kalau ada, inspeksi ini nempel ke kos yang sudah ada (nama/lokasi sudah tahu,
    /// jadi Report bisa langsung "Simpan"). Kalau nil, ini kos baru — nama & harga
    /// baru diisi belakangan di NewReportInfoView.
    let existingProperty: KosProperty?

    /// Diisi otomatis lewat GPS pas flow kos-baru dimulai (lihat RoomTypeSelectionView).
    @Published var autoDetectedLocation: String = ""

    init(existingProperty: KosProperty?) {
        self.existingProperty = existingProperty
    }
}
