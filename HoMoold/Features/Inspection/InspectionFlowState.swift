//
//  InspectionFlowState.swift
//  HoMoold
//

import Combine
import Foundation
import UIKit

enum InspectionStep: Hashable {
    case capture
    case condition // termasuk lokasi rumah kalau propertinya belum punya lokasi
    case report
}

@MainActor
final class InspectionFlowState: ObservableObject {
    @Published var path: [InspectionStep] = []
    @Published var roomType: RoomType?
    @Published var capturedFindings: [Finding] = []
    /// Foto yang diambil tapi 0 jamur kedeteksi — lihat CaptureViewModel.Outcome.
    @Published var capturedPhotos: [UIImage] = []
    @Published var resultInspection: RoomInspection?

    /// Rumahnya selalu sudah ada duluan — dibuat lewat "Simpan Rumah" dari FAB
    /// Home SEBELUM masuk ke flow ini (lihat SaveHouseSheet), jadi Report di
    /// sini selalu langsung "Simpan", gak perlu tanya nama lagi belakangan.
    let existingProperty: KosProperty

    /// Diisi di ConditionFormView (prefill dari `existingProperty.location` —
    /// dengan prefill GPS kalau rumahnya belum punya lokasi sama sekali).
    @Published var location: HomeLocation

    // Diisi di ConditionFormView — kondisi ruangan yang dilaporin manual sama user.
    @Published var hasAC = false
    @Published var hasWindow = false
    @Published var dampness = false
    @Published var wallCrack = false

    init(existingProperty: KosProperty) {
        self.existingProperty = existingProperty
        self.location = existingProperty.location
    }
}
