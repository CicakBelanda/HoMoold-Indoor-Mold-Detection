//
//  MoldMeasureView.swift
//  HoMoold
//
//  Layar test standalone: arahkan kamera ke noda jamur/lembap, bounding
//  box-nya digambar live di atas feed kamera, dan luasnya (cm²) muncul terus
//  ter-update selama belum di-"Bekukan". Cuma buat validasi teknis (LiDAR +
//  deteksi), BUKAN bagian dari flow inspeksi asli — masuknya lewat tombol
//  debug kecil di HomeListView, bukan dari alur "+ Mulai pemeriksaan".
//

import SwiftUI

struct MoldMeasureView: View {
    @StateObject private var viewModel: MoldMeasureViewModel
    @ObservedObject private var arSession: ARDepthCaptureSession
    @Environment(\.dismiss) private var dismiss

    init() {
        let vm = MoldMeasureViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _arSession = ObservedObject(wrappedValue: vm.arSession)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if arSession.isLiDARSupported {
                ARPassthroughView(session: arSession.session)
                    .ignoresSafeArea()

                ForEach(viewModel.instances) { instance in
                    BoundingBoxOverlay(findingClass: instance.findingClass, boundingBox: instance.box)
                        .ignoresSafeArea()
                        .animation(.linear(duration: 0.3), value: instance.box)
                }
                .allowsHitTesting(false)
            } else {
                unsupportedView
            }

            VStack {
                topBar
                Spacer()
                if let banner = statusBannerText {
                    statusBanner(banner)
                        .padding(.bottom, 10)
                }
                resultsPanel
                if arSession.isLiDARSupported {
                    freezeButton
                        .padding(.bottom, 32)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .statusBarHidden()
    }

    private var statusBannerText: String? {
        if viewModel.modelUnavailable {
            return "Model deteksi belum ketemu di bundle app."
        }
        if let tracking = arSession.trackingMessage {
            return tracking
        }
        if viewModel.isWaitingForDepth {
            return "Nunggu data depth dari LiDAR..."
        }
        return nil
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .accessibilityLabel("Tutup")

            Spacer()

            Text("Test Ukur Luas Jamur (LiDAR)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func statusBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var resultsPanel: some View {
        if !viewModel.instances.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.instances) { instance in
                    HStack {
                        Text(instance.findingClass.displayNameID)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(instance.areaText ?? "menghitung...")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)

                    if let warning = instance.rangeWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(14)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private var freezeButton: some View {
        Button {
            viewModel.toggleFreeze()
        } label: {
            Text(viewModel.isFrozen ? "Lanjutkan Scan" : "Bekukan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(viewModel.isFrozen ? Color.accentColor : Color.white.opacity(0.25), in: Capsule())
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sensor.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text("Gak ada sensor LiDAR")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Fitur ini cuma jalan di iPhone/iPad Pro yang punya LiDAR.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    MoldMeasureView()
}
