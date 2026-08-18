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

    /// Dipanggil sebagai ganti maju ke loading, kalau kamera dibuka DI LUAR alur
    /// inspeksi — mis. nambah foto ke ruangan yang udah tersimpan dari halaman
    /// Report. `nil` = perilaku normal (lanjut ke loading → report).
    private var onFinish: (() -> Void)?

    /// `@MainActor` di init-nya WAJIB: `CaptureViewModel` dan
    /// `ARDepthCaptureSession` dua-duanya `@MainActor`, jadi bikin instance-nya
    /// + baca `vm.arSession` dari init yang nonisolated bikin warning
    /// "main actor-isolated ... in a nonisolated context". View-nya toh selalu
    /// dibangun di main thread, jadi ini cuma nyatain yang emang udah terjadi.
    @MainActor
    init(flow: InspectionFlowState, onFinish: (() -> Void)? = nil) {
        self.flow = flow
        self.onFinish = onFinish
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
        // Layar ini di-push lewat NavigationStack (dari GuidanceView), jadi tanpa
        // ini bakal ada 2 tombol tutup: back chevron sistem DAN tombol X kita
        // sendiri di panel atas.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Scanning

    /// Chrome kamera sesuai Figma 1339:7845 / 7812: dua panel kaca (atas &
    /// bawah) dengan sudut dalam membulat, pil status ngambang di tengah atas.
    private var scanningLayer: some View {
        VStack(spacing: 0) {
            topPanel

            statusPill
                .padding(.top, 34)

            Spacer()

            bottomPanel
        }
    }

    // MARK: Panel atas — tombol tutup, bantuan, bar progres

    private var topPanel: some View {
        VStack(spacing: 12) {
            HStack {
                // Tombol chrome kamera sengaja NGGAK diwarnai brand — pakai
                // warna label bawaan di atas kaca, biar kelihatan sebagai
                // kontrol sistem, bukan aksi utama.
                // X, ?, dan flash sengaja UKURANNYA SAMA PERSIS (headline /
                // 20pt / controlSize .large). Ketiganya kontrol chrome yang
                // setara, jadi kalau ukurannya beda-beda malah keliatan salah
                // satu lebih penting.
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.primary)
                .accessibilityLabel("Close camera")

                Spacer()

                // Balik ke panduan cara motret — di Figma tombol "?" kecil di
                // kanan atas. Dipakai buat balik ke referensi jamur tanpa harus
                // keluar dari kamera.
                Button {
                    flow.path.append(.moldReference)
                } label: {
                    Image(systemName: "questionmark")
                        .font(.headline)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.primary)
                .accessibilityLabel("What does mold look like?")
            }
            .padding(.horizontal, 22)

            progressBar
                .padding(.horizontal, 26)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            UnevenRoundedRectangle(
                bottomLeadingRadius: 40,
                bottomTrailingRadius: 40,
                style: .continuous
            )
            .fill(.black.opacity(0.45))
            .ignoresSafeArea(edges: .top)
        }
    }

    /// Bar 5pt radius 100. Isinya progres "nahan kamera": abu pas belum ada apa-apa,
    /// jingga sambil ngisi, hijau penuh pas siap dijepret.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))

                Capsule()
                    .fill(progressColor)
                    .frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 5)
        .animation(.easeOut(duration: 0.25), value: progressFraction)
    }

    private var progressFraction: CGFloat {
        switch viewModel.phase {
        case .scanning: return 0
        case .stabilizing: return CGFloat(viewModel.stabilizeProgress)
        case .ready: return 1
        }
    }

    private var progressColor: Color {
        viewModel.phase == .ready ? .green : .orange
    }

    // MARK: Pil status

    private var statusPill: some View {
        Text(statusBannerText ?? viewModel.guidanceText)
            .font(viewModel.phase == .ready ? .title3.weight(.medium) : .headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
    }

    // MARK: Panel bawah — jepret & lampu

    private var bottomPanel: some View {
        ZStack {
            captureButton

            HStack {
                // Hitungan foto yang udah keterima di ruangan ini — dulu ada di
                // pojok kanan atas, dipindah ke sini biar panel atas tetap
                // bersih kayak desainnya.
                let count = viewModel.acceptedFindings.count + viewModel.acceptedPhotos.count
                if count > 0 {
                    Text("\(count)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(.white.opacity(0.2), in: Circle())
                        .accessibilityLabel("\(count) photo\(count == 1 ? "" : "s") taken")
                }

                Spacer()

                flashButton
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(.black.opacity(0.45))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Jepret MANUAL — nggak ada auto-capture lagi (lihat CaptureViewModel).
    /// Sengaja tetap bisa dipencet walau belum hijau: kadang deteksinya kedip
    /// padahal jamurnya jelas keliatan, dan ngunci tombolnya bikin user mentok.
    /// Bedanya cuma di tampilan — putih terang pas siap, redup pas belum.
    private var captureButton: some View {
        Button {
            viewModel.capture()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(viewModel.phase == .ready ? 0.9 : 0.4), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(viewModel.phase == .ready ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 62, height: 62)
            }
        }
        .accessibilityLabel("Take photo")
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
    }

    private var flashButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.headline)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .tint(.primary)
        .accessibilityLabel(viewModel.isTorchOn ? "Turn flash off" : "Turn flash on")
    }

    // MARK: - Preview hasil jepretan

    private func previewLayer(_ result: CaptureViewModel.CapturedResult) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Captured shot")
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

                        Button("Another Spot") { viewModel.acceptAndScanAnother() }
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
            Text("No mold detected in this shot.")
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
                        Text(detection.areaText ?? "area couldn't be measured")
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
                Text("Processing photo...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Chrome

    /// Pesan yang lebih penting daripada panduan biasa. Diurut dari yang paling
    /// mendesak — `captureError` ikut ke sini karena panel lama yang dulu
    /// nampung error-nya udah nggak ada, dan error yang nggak keliatan bikin user
    /// mencet-mencet tombol tanpa tau kenapa nggak jalan.
    private var statusBannerText: String? {
        if viewModel.modelUnavailable {
            return "Detection model not found in the app bundle."
        }
        if let error = viewModel.captureError {
            return error
        }
        if let tracking = arSession.trackingMessage {
            return tracking
        }
        if viewModel.isWaitingForDepth {
            return "Waiting for LiDAR depth data..."
        }
        if viewModel.isLightTooDim {
            return "Lighting is too dim — move to a brighter area or turn on the flash."
        }
        return nil
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sensor.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text("No LiDAR sensor")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Measuring mold area only works on an iPhone/iPad Pro with LiDAR.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Skip without photos") { finish() }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 40)
                .padding(.top, 8)
        }
    }

    private func finish() {
        let outcome = viewModel.acceptAndFinish()
        flow.capturedFindings = outcome.findings
        flow.capturedPhotos = outcome.photos
        // "Done" itu langkah TERAKHIR di jalur ada-jamur: langsung ke loading →
        // report. Jadi ada dua jalur yang ketemu di loading:
        //   Visible Mold mati  -> Submit di form kondisi -> loading
        //   Visible Mold nyala -> Next -> guidance -> kamera -> Done -> loading
        //
        // Path-nya di-GANTI (bukan di-append) supaya guidance & kamera nggak
        // ketinggalan di stack — kalau ketinggalan, balik dari report bisa
        // mendarat di kamera atau nge-trigger loading lagi.
        if let onFinish {
            onFinish()
        } else {
            flow.path = [.loading]
        }
    }
}

#Preview {
    let property = KosProperty(name: "Sample Property", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return CaptureView(flow: InspectionFlowState(existingProperty: property))
}
