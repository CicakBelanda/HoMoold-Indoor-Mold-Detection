//
//  CaptureView.swift
//  HoMoold
//
//  Layar ambil foto jamur pas inspeksi. Pas ngarahin kamera SENGAJA gak ada
//  overlay deteksi sama sekali — cuma indikator merah/kuning/hijau + teks
//  panduan, biar user fokus ngarahin kamera dulu. Overlay bounding box + mask
//  + angka luas baru muncul di preview setelah gambarnya diambil (lihat
//  CaptureViewModel buat alurnya).
//
//  Bisa jepret lebih dari satu titik jamur per ruangan: "Jamur Lain" nerima
//  foto yang lagi di-preview terus balik scan; "Selesai" nerima (kalau ada
//  yang lagi di-preview) dan nutup layar ini, findings-nya dibawa ke step
//  Condition berikutnya (lihat InspectionFlowView).
//

import SwiftUI

struct CaptureView: View {
    @ObservedObject var flow: InspectionFlowState
    @StateObject private var viewModel: CaptureViewModel
    @ObservedObject private var arSession: ARDepthCaptureSession
    @Environment(\.dismiss) private var dismiss

    init(flow: InspectionFlowState) {
        self.flow = flow
        let vm = CaptureViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _arSession = ObservedObject(wrappedValue: vm.arSession)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if arSession.isLiDARSupported {
                ARPassthroughView(session: arSession.session)
                    .ignoresSafeArea()
                scanningLayer
            } else {
                unsupportedView
            }

            if let captured = viewModel.captured {
                previewLayer(captured)
            }

            if viewModel.isCapturing {
                processingLayer
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .statusBarHidden()
        // Layar ini di-push lewat NavigationStack (dari RoomTypeSelectionView),
        // jadi tanpa ini bakal ada 2 tombol back: back chevron sistem DAN
        // tombol custom kita di topBar.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Scanning

    private var scanningLayer: some View {
        VStack(spacing: 0) {
            topBar
            guidanceCard
                .padding(.horizontal, 24)
                .padding(.top, 12)
            Spacer()
            captureButton
                .padding(.bottom, 32)
        }
    }

    private var indicatorColor: Color {
        switch viewModel.phase {
        case .scanning: return .red
        case .stabilizing: return .orange
        case .ready: return .green
        }
    }

    private var guidanceCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))

                Text(statusBannerText ?? viewModel.guidanceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Bar progres nahan kamera — cuma muncul pas lagi nunggu stabil.
            if viewModel.phase == .stabilizing {
                ProgressView(value: viewModel.stabilizeProgress)
                    .tint(.orange)
            }

            if let error = viewModel.captureError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
    }

    /// Tombol jepret. Tetap bisa dipencet kapan aja (biar gak nyebelin kalau
    /// deteksinya lagi kedip-kedip), tapi tampilannya jelas beda pas udah siap.
    private var captureButton: some View {
        Button {
            viewModel.capture()
        } label: {
            ZStack {
                Circle()
                    .stroke(viewModel.phase == .ready ? Color.green : .white.opacity(0.6), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(viewModel.phase == .ready ? Color.green : .white.opacity(0.6))
                    .frame(width: 62, height: 62)
            }
        }
        .accessibilityLabel("Take photo")
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
    }

    // MARK: - Preview hasil jepretan

    private func previewLayer(_ result: CaptureViewModel.CapturedResult) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Capture Result")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Gambar + overlay dibungkus ZStack ber-aspect-ratio yang sama
                // dengan gambarnya, supaya koordinat ternormalisasi box
                // persis nempel di gambarnya (bukan di frame yang lebih besar).
                //
                // Mask (kalau modelnya punya) sengaja CUMA dipakai buat hitung
                // luas di ARAreaCalculator (lihat CaptureViewModel.capture()),
                // gak digambar ke layar — yang ditampilin ke user tetap kotak
                // deteksi biasa (BoundingBoxOverlay), bukan bentuk mask-nya.
                ZStack {
                    Image(uiImage: result.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    ForEach(result.detections) { detection in
                        BoundingBoxOverlay(findingClass: .mold, boundingBox: detection.box)
                    }
                }
                .aspectRatio(result.image.size.width / max(result.image.size.height, 1), contentMode: .fit)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)

                resultList(result)

                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button("Retake", systemImage: "arrow.counterclockwise") { viewModel.retake() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2), in: Capsule())

                        Button("Another Mold") { viewModel.acceptAndScanAnother() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2), in: Capsule())
                    }

                    Button("Done") { finish() }
                        .buttonStyle(.pillProminent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func resultList(_ result: CaptureViewModel.CapturedResult) -> some View {
        if result.detections.isEmpty {
            Text("No mold detected in this photo.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.detections) { detection in
                    HStack(alignment: .firstTextBaseline) {
                        Text("Mold")
                            .font(.subheadline.weight(.semibold))
                        Text(String(format: "(%.0f%%)", detection.confidence * 100))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(detection.areaText ?? "area could not be measured")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)

                    if let note = detection.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var processingLayer: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Processing image...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Chrome

    private var statusBannerText: String? {
        if viewModel.modelUnavailable {
            return "Detection model not found in the app bundle."
        }
        if let tracking = arSession.trackingMessage {
            return tracking
        }
        if viewModel.isWaitingForDepth {
            return "Waiting for depth data from LiDAR..."
        }
        return nil
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Back")

            Spacer()

            let acceptedCount = viewModel.acceptedFindings.count + viewModel.acceptedPhotos.count
            if acceptedCount > 0 {
                Text("\(acceptedCount) photos taken")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sensor.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text("No LiDAR sensor")
                .font(.headline)
                .foregroundStyle(.white)
            Text("The mold area measurement feature only works on iPhone/iPad Pro models with LiDAR.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Skip without photo") { finish() }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 40)
                .padding(.top, 8)
        }
    }

    private func finish() {
        let outcome = viewModel.acceptAndFinish()
        flow.capturedFindings = outcome.findings
        flow.capturedPhotos = outcome.photos
        flow.path.append(.condition)
    }
}

#Preview {
    let property = KosProperty(name: "Sample Property", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return CaptureView(flow: InspectionFlowState(existingProperty: property))
}
