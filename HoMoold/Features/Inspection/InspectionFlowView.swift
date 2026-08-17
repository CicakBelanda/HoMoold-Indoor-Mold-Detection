//
//  InspectionFlowView.swift
//  HoMoold
//
//  Container navigasi "Add new Room" — rumahnya selalu sudah ada duluan
//  (dibuat lewat modal "Add New House" dari FAB Home), jadi flow ini selalu nempel
//  ke rumah yang sudah punya nama.
//
//  Alur:
//
//    ConditionFormView  <- layar pertama, langsung kebuka pas user tap
//                          "Add new Room" (nggak ada lagi layar pilih tipe
//                          ruangan terpisah — nama & tipe diisi di form ini)
//      |
//      |-- (opsional, kalau user centang "Visible mold") --> GuidanceView
//      |                                                        |
//      |                                                        v
//      |<---------------------- balik ke form -------------- CaptureView
//      |
//      v  Submit
//    AnalyzingLoadingView -> ReportView
//
//  Kamera itu SUB-FLOW dari form kondisi, bukan langkah berurutan. Jadi
//  guidance-nya muncul pas kamera mau dibuka (sesuai desain), dan setelah
//  motret user balik ke form buat nyelesaiin sisanya lalu Submit.
//

import SwiftUI

struct InspectionFlowView: View {
    let store: AppDataStore

    @StateObject private var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(store: AppDataStore, existingProperty: KosProperty) {
        self.store = store
        _flow = StateObject(wrappedValue: InspectionFlowState(existingProperty: existingProperty))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            ConditionFormView(flow: flow)
                .navigationDestination(for: InspectionStep.self) { step in
                    switch step {
                    case .guidance:
                        GuidanceView(flow: flow)
                    case .capture:
                        CaptureView(flow: flow)
                    case .moldReference:
                        MoldReferenceView()
                    case .loading:
                        AnalyzingLoadingView(flow: flow)
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
