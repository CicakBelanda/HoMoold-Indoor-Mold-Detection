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

            // NGGAK ada lagi gerbang "device ini nggak didukung". LiDAR cuma
            // buat ngukur luas; deteksi jamurnya jalan di gambar kamera biasa.
            // Di iPhone non-Pro layar ini tetap kepake penuh — yang hilang cuma
            // angka cm²-nya, dan itu dibilangin lewat `noLiDARNote` di bawah.
            scanningLayer

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

    /// Susunannya niru app Camera bawaan: panel hitam solid di atas, jendela
    /// kamera di tengah, panel hitam solid di bawah.
    ///
    /// Preview-nya sengaja DI DALAM VStack ini, bukan lapisan full-bleed di
    /// belakang chrome-nya. Itu bukan cuma soal tampilan: hasil jepretan
    /// dipotong persis seluas view preview (lihat PreviewCrop di
    /// CaptureViewModel), jadi kalau ada bagian preview yang ketutupan panel,
    /// foto hasilnya bakal ngandung isi yang user nggak pernah lihat. Ditaruh
    /// di antara dua panel, seluruh preview dijamin kelihatan.
    private var scanningLayer: some View {
        VStack(spacing: 0) {
            topPanel

            ZStack(alignment: .top) {
                cameraPreview

                statusPill
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomPanel
        }
    }

    /// Jendela kamera 3:4 — rasio yang sama persis dengan frame sensor ARKit
    /// setelah diputar ke portrait.
    ///
    /// Ini yang bikin "yang dijepret = yang dipreview" jadi gratis: waktu rasio
    /// view-nya sama dengan rasio frame-nya, aspect-fill nggak motong apa-apa,
    /// jadi nggak ada isi yang kebuang. Versi full-bleed sebelumnya bikin frame
    /// 3:4 dipaksa ngisi layar yang jauh lebih jangkung — kiri-kanannya kepotong
    /// habis.
    private var cameraPreview: some View {
        ARPassthroughView(session: arSession.session)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            // Ukuran view ini dilaporin ke view model: dia yang nentuin bagian
            // mana dari frame kamera yang beneran kelihatan.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { viewModel.previewSize = $0 }
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

            noLiDARNote
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        // Hitam SOLID dan LURUS, kayak app Camera bawaan. Dulu kapsul kaca
        // hitam 45% dengan sudut bawah membulat 40pt — itu ngambang di atas
        // gambar kamera, jadi tepi jendelanya nggak pernah jelas dan preview
        // yang keintip di balik panel bikin bingung batas fotonya sampai mana.
        .background(Color.black.ignoresSafeArea(edges: .top))
    }

    /// Satu baris kecil buat device tanpa LiDAR. Sengaja BUKAN pil status yang
    /// di tengah layar: itu tempatnya panduan yang berubah-ubah ("Detected,
    /// hold steady"), dan kalau ditempelin peringatan permanen di situ,
    /// panduannya jadi ketutup terus. Ini keadaan device yang nggak bakal
    /// berubah — cukup dinyatakan sekali, tenang, di pinggir.
    @ViewBuilder
    private var noLiDARNote: some View {
        if !arSession.isLiDARSupported {
            Text("No LiDAR on this device — mold is still detected, but the area can't be measured.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
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
        .background(Color.black.ignoresSafeArea(edges: .bottom))
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

                    // Dinomorin sesuai urutan di daftar bawah — `detections`
                    // udah diurut dari confidence tertinggi waktu dirakit di
                    // CaptureViewModel, jadi indeksnya konsisten di dua tempat.
                    ForEach(Array(result.detections.enumerated()), id: \.element.id) { index, detection in
                        BoundingBoxOverlay(
                            findingClass: .mold,
                            boundingBox: detection.box,
                            label: moldLabel(index, total: result.detections.count)
                        )
                    }
                }
                .aspectRatio(result.image.size.width / max(result.image.size.height, 1), contentMode: .fit)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)

                resultList(result)

                VStack(spacing: 10) {
                    // Kaca sistem, bukan kapsul putih 20% yang digambar sendiri
                    // — dulu itu cuma NIRU tampilan kaca dan nggak ikut efek
                    // Liquid Glass beneran (nggak ada refraksi, nggak nyesuain
                    // isi di belakangnya).
                    //
                    // `.tint(.white)` dipasang eksplisit: app dikunci light mode
                    // (lihat HoMooldApp), jadi `.primary` di sini jatuh jadi
                    // HITAM di atas latar preview yang hitam.
                    // `.frame(maxWidth: .infinity)` ditaruh DI LABEL, bukan di
                    // Button-nya. Kalau dipasang di luar, yang melar cuma area
                    // ketuknya — kapsul kacanya tetap nyempit ngikutin lebar
                    // teks, dan sisanya jadi ruang kosong.
                    HStack(spacing: 10) {
                        Button {
                            viewModel.retake()
                        } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            viewModel.acceptAndScanAnother()
                        } label: {
                            Text("Another Spot")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(.white)

                    Button("Done") { finish() }
                        .buttonStyle(.pillProminent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    /// "Mold 1", "Mold 2", ... — tapi cuma kalau emang ada lebih dari satu.
    /// Satu temuan yang dilabeli "Mold 1" malah bikin user nyari "Mold 2" yang
    /// nggak ada.
    private func moldLabel(_ index: Int, total: Int) -> String {
        total > 1 ? "Mold \(index + 1)" : "Mold"
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
                ForEach(Array(result.detections.enumerated()), id: \.element.id) { index, detection in
                    HStack(alignment: .firstTextBaseline) {
                        Text(moldLabel(index, total: result.detections.count))
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
