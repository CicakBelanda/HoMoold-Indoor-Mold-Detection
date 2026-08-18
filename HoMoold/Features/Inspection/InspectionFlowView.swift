//
//  InspectionFlowView.swift
//  HoMoold
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
                            // Save DAN Discard sama-sama nutup cover-nya, jadi
                            // dua-duanya mendarat di daftar ruangan rumah ini.
                            // Discard nggak boleh cuma `dismiss()` dari dalam
                            // ReportView: itu nge-pop balik ke layar loading,
                            // yang langsung ngedorong user maju ke report lagi.
                            ReportView(
                                store: store,
                                draftInspection: inspection,
                                existingPropertyID: flow.existingProperty.id,
                                location: flow.location,
                                onSaved: { dismiss() },
                                onDiscard: { dismiss() }
                            )
                        }
                    }
                }
        }
    }
}
