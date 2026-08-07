//
//  InspectionFlowView.swift
//  HoMoold
//
//  Container navigasi New Inspection. Dua mode:
//  - existingProperty != nil: nempel ke kos yang sudah ada (dari tombol + di
//    halaman detail kos) — Report langsung "Simpan", tanpa tanya nama lagi.
//  - existingProperty == nil: kos baru (dari FAB Home) — nama & harga baru
//    diisi di NewReportInfoView setelah lihat hasil Report.
//

import SwiftUI

struct InspectionFlowView: View {
    let store: AppDataStore
    private let detectionService: MoldDetectionService = RealMoldDetectionService()

    @StateObject private var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss

    init(store: AppDataStore, existingProperty: KosProperty? = nil) {
        self.store = store
        _flow = StateObject(wrappedValue: InspectionFlowState(existingProperty: existingProperty))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            RoomTypeSelectionView(flow: flow)
                .navigationDestination(for: InspectionStep.self) { step in
                    switch step {
                    case .record:
                        RecordVideoView(flow: flow)
                    case .preview:
                        VideoPreviewView(flow: flow)
                    case .loading:
                        AnalyzingLoadingView(flow: flow, detectionService: detectionService)
                    case .report:
                        if let inspection = flow.resultInspection {
                            if let existing = flow.existingProperty {
                                ReportView(
                                    store: store,
                                    draftInspection: inspection,
                                    existingPropertyID: existing.id,
                                    onSaved: { dismiss() }
                                )
                            } else {
                                ReportView(
                                    store: store,
                                    draftInspection: inspection,
                                    onContinueToNaming: { flow.path.append(.newReportInfo) }
                                )
                            }
                        }
                    case .newReportInfo:
                        if let inspection = flow.resultInspection {
                            NewReportInfoView(
                                store: store,
                                inspection: inspection,
                                autoDetectedLocation: flow.autoDetectedLocation,
                                onSaved: { dismiss() },
                                onCancel: { dismiss() }
                            )
                        }
                    }
                }
        }
    }
}
