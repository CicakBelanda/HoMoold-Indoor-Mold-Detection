//
//  InspectionFlowView.swift
//  HoMoold
//
//  Container navigasi untuk seluruh alur New Inspection (Bagian 4 & 5 spesifikasi):
//  pilih kos -> pilih ruangan -> rekam -> preview -> loading -> report -> simpan.
//

import SwiftUI

struct InspectionFlowView: View {
    let store: AppDataStore
    private let detectionService: MoldDetectionService = MockMoldDetectionService()

    @StateObject private var flow = InspectionFlowState()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $flow.path) {
            SelectPropertyView(store: store, flow: flow)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Batal") { dismiss() }
                    }
                }
                .navigationDestination(for: InspectionStep.self) { step in
                    switch step {
                    case .roomType:
                        RoomTypeSelectionView(flow: flow)
                    case .record:
                        RecordVideoView(flow: flow)
                    case .preview:
                        VideoPreviewView(flow: flow)
                    case .loading:
                        AnalyzingLoadingView(flow: flow, detectionService: detectionService)
                    case .report:
                        if let inspection = flow.resultInspection {
                            ReportView(
                                store: store,
                                draftInspection: inspection,
                                propertyName: flow.propertyName,
                                propertyLocation: flow.propertyLocation,
                                onSaved: { dismiss() }
                            )
                        }
                    }
                }
        }
    }
}
