//
//  MoldMeasureView.swift
//  HoMoold
//
//  Layar test standalone: arahkan kamera ke noda jamur, outline-nya digambar
//  live di atas feed kamera (mask kalau model-nya segmentasi, bounding box
//  kalau enggak — lihat TrackedDetection.mask), dan luasnya (cm²) muncul
//  terus ter-update selama belum di-"Bekukan". Cuma buat validasi teknis
//  (LiDAR + deteksi), BUKAN bagian dari flow inspeksi asli — masuknya lewat
//  tombol debug kecil di HomeListView, bukan dari alur "+ Mulai pemeriksaan".
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
                    if let mask = instance.mask {
                        MaskOverlayView(instances: [mask])
                            .ignoresSafeArea()
                    } else {
                        BoundingBoxOverlay(findingClass: instance.findingClass, boundingBox: instance.box)
                            .ignoresSafeArea()
                            .animation(.linear(duration: 0.3), value: instance.box)
                    }
                }
                .allowsHitTesting(false)
            } else {
                unsupportedView
            }

            VStack {
                topBar
                if arSession.isLiDARSupported {
                    debugPanel
                }
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

    /// Ringkasan tiap tick (anchor count, skor mold tertinggi, threshold, dst.)
    /// langsung di layar — biar bisa didiagnosa dari HP tanpa buka console Xcode.
    /// Kalau tulisannya gak berubah-ubah tiap ~0.4 detik, berarti `tick()` gak
    /// pernah kepanggil sama sekali (beda masalah lagi dari model-nya sendiri).
    private var debugPanel: some View {
        Text(viewModel.debugText.isEmpty ? "menunggu frame pertama..." : viewModel.debugText)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.green)
            .multilineTextAlignment(.leading)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 6)
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

            detectionIndicator
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Titik gede yang jelas ijo/merah — jauh lebih gampang diliat sekilas
    /// daripada baca teks angka. Ijo = ada sesuatu yang lolos threshold tick
    /// ini (walau area-nya masih dihitung/di luar jangkauan LiDAR). Merah =
    /// belum ada apa-apa yang lolos threshold sama sekali.
    private var detectionIndicator: some View {
        Circle()
            .fill(viewModel.instances.isEmpty ? Color.red : Color.green)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .animation(.easeInOut(duration: 0.2), value: viewModel.instances.isEmpty)
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
