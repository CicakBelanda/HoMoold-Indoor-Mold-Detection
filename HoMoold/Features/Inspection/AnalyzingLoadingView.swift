//
//  AnalyzingLoadingView.swift
//  HoMoold
//

import Combine
import SwiftUI

struct AnalyzingLoadingView: View {
    @ObservedObject var flow: InspectionFlowState
    let detectionService: MoldDetectionService

    private let messages = [
        "Menganalisis video...",
        "Mencari tanda lembap dan retak...",
        "Menghitung skor risiko...",
    ]

    @State private var messageIndex = 0
    private let timer = Timer.publish(every: 1.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            Text(messages[messageIndex])
                .font(.headline)
                .foregroundStyle(.secondary)
                .transition(.opacity)
                .id(messageIndex)
                .animation(.easeInOut, value: messageIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .onReceive(timer) { _ in
            messageIndex = (messageIndex + 1) % messages.count
        }
        .task {
            guard let roomType = flow.roomType, let videoURL = flow.recordedVideoURL else { return }
            let inspection = await detectionService.analyze(videoURL: videoURL, roomType: roomType)
            flow.resultInspection = inspection
            flow.path.append(.report)
        }
    }
}

#Preview {
    NavigationStack {
        AnalyzingLoadingView(flow: InspectionFlowState(existingProperty: nil), detectionService: MockMoldDetectionService())
    }
}
