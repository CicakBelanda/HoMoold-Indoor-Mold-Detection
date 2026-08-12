//
//  InspectionFlowView.swift
//  HoMoold
//
//  Container navigasi "Tambah Ruangan" — rumahnya selalu sudah ada duluan
//  (dibuat lewat SaveHouseSheet dari FAB Home), jadi flow ini selalu nempel
//  ke rumah yang sudah punya nama; Report langsung "Simpan".
//
//  Alur: RoomTypeSelectionView -> CaptureView (ambil foto jamur, bisa lebih
//  dari satu) -> ConditionFormView (kondisi ruangan + lokasi kalau rumahnya
//  belum punya lokasi) -> ReportView.
//

import SwiftUI

struct InspectionFlowView: View {
    let store: AppDataStore

    @StateObject private var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss

    init(store: AppDataStore, existingProperty: KosProperty) {
        self.store = store
        _flow = StateObject(wrappedValue: InspectionFlowState(existingProperty: existingProperty))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            RoomTypeSelectionView(flow: flow)
                .navigationDestination(for: InspectionStep.self) { step in
                    switch step {
                    case .capture:
                        CaptureView(flow: flow)
                    case .condition:
                        ConditionFormView(flow: flow)
                    case .report:
                        if let inspection = flow.resultInspection {
                            ReportView(
                                store: store,
                                draftInspection: inspection,
                                existingPropertyID: flow.existingProperty.id,
                                location: flow.location,
                                onSaved: { dismiss() }
                            )
                        }
                    }
                }
        }
    }
}
