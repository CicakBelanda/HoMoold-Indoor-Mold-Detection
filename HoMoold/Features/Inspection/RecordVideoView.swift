//
//  RecordVideoView.swift
//  HoMoold
//

import Combine
import SwiftUI

struct RecordVideoView: View {
    @ObservedObject var flow: InspectionFlowState
    @StateObject private var camera = CameraService()
    @StateObject private var guide: GuidedRecordingController

    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(flow: InspectionFlowState) {
        self.flow = flow
        _guide = StateObject(wrappedValue: GuidedRecordingController(roomType: flow.roomType))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isSessionReady {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else if camera.permissionDenied {
                permissionDeniedView
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                GuidedInstructionBar(
                    stepIndex: guide.stepIndex,
                    totalSteps: guide.totalSteps,
                    instructionText: guide.instructionText,
                    canSkip: guide.canSkip,
                    onSkip: { guide.skip() }
                )
                Spacer()
            }

            VStack {
                Spacer()
                recordButton
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle(flow.roomType?.rawValue ?? "Rekam Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { camera.configureIfNeeded() }
        .onDisappear { camera.stopSession() }
        .onReceive(camera.$liveDetections) { detections in
            guide.processDetections(detections)
        }
        .onReceive(tickTimer) { _ in
            guide.tick()
        }
        .onChange(of: camera.lastRecordedURL) { _, url in
            guard let url else { return }
            flow.recordedVideoURL = url
            flow.path.append(.preview)
        }
    }

    private var recordButton: some View {
        Button {
            if camera.isRecording {
                camera.stopRecording()
            } else {
                camera.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(guide.showDoneHint ? Color.accentColor : .white, lineWidth: guide.showDoneHint ? 5 : 4)
                    .frame(width: 76, height: 76)
                if camera.isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .accessibilityLabel(camera.isRecording ? "Berhenti merekam" : "Mulai merekam")
        .disabled(!camera.isSessionReady)
        .overlay(alignment: .top) {
            if guide.showDoneHint {
                Text("Selesai?")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor, in: Capsule())
                    .offset(y: -28)
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text("Akses kamera dibutuhkan")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Nyalakan akses kamera & mikrofon untuk HoMoold di Pengaturan iOS.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Buka Pengaturan") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.pillProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }
}

#Preview {
    NavigationStack {
        RecordVideoView(flow: InspectionFlowState(existingProperty: nil))
    }
}
