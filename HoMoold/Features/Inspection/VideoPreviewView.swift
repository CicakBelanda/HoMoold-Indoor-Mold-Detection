//
//  VideoPreviewView.swift
//  HoMoold
//

import AVKit
import SwiftUI

struct VideoPreviewView: View {
    @ObservedObject var flow: InspectionFlowState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let url = flow.recordedVideoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea(edges: .top)
            } else {
                Color.black
            }

            HStack(spacing: 12) {
                Button {
                    flow.recordedVideoURL = nil
                    if flow.path.last == .preview {
                        flow.path.removeLast()
                    }
                } label: {
                    Text("Ambil Ulang")
                }
                .buttonStyle(.pillSecondary)

                Button {
                    flow.path.append(.loading)
                } label: {
                    Text("Lanjut")
                }
                .buttonStyle(.pillProminent)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        VideoPreviewView(flow: InspectionFlowState())
    }
}
