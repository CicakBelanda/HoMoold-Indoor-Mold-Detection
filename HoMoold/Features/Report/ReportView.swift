//
//  ReportView.swift
//  HoMoold
//

import SwiftUI

struct ReportView: View {
    @StateObject private var viewModel: ReportViewModel
    @State private var viewerItem: ImageViewerItem?
    @State private var photoIndex = 0
    @State private var showRiskInfo = false
    /// Lebar kolom konten, diukur pas layout. Dipakai buat ngitung sisi kartu
    /// foto yang persegi — nggak bisa dari `UIScreen`, itu ngabaikan padding
    /// konten dan bakal meleset di iPad/Split View.
    @State private var contentWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    private var onSaved: (() -> Void)?
    /// Dipanggil waktu user tap "Discard". Diisi sama InspectionFlowView biar
    /// tombolnya nutup SELURUH flow inspeksi dan balik ke daftar ruangan —
    /// `dismiss()` doang cuma nge-pop satu layar, jadi user malah mendarat di
    /// layar loading dan langsung kedorong maju ke report lagi.
    private var onDiscard: (() -> Void)?

    /// Mode draft: hasil analisis baru, nempel ke rumah yang sudah ada — tombol
    /// Save langsung menyimpan (`location` cuma beneran ditulis kalau rumahnya
    /// belum punya lokasi, lihat AppDataStore.attachInspection).
    @MainActor
    init(
        store: AppDataStore,
        draftInspection: RoomInspection,
        existingPropertyID: UUID,
        location: HomeLocation,
        onSaved: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: draftInspection,
            source: .draftExisting(propertyID: existingPropertyID, location: location),
            isReadOnly: false
        ))
        self.onSaved = onSaved
        self.onDiscard = onDiscard
    }

    /// Mode "saved": lihat ulang temuan yang sudah tersimpan, read-only.
    @MainActor
    init(store: AppDataStore, propertyID: UUID, roomID: UUID) {
        let existing = store.properties.first(where: { $0.id == propertyID })?.rooms.first(where: { $0.id == roomID })
        let fallback = RoomInspection(roomType: .bedroom, riskLevel: .low, riskScore: 0, findings: [], hasAC: false, hasWindow: false, dampness: false, wallCrack: false, date: Date())
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: existing ?? fallback,
            source: .saved(propertyID: propertyID),
            isReadOnly: true
        ))
        self.onSaved = nil
        self.onDiscard = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                photoStack
                predictionCard
                healthRiskCard
                recommendationsCard
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        }
        // Latar lewat `.background`, bukan sibling ZStack — lihat catatan di
        // MoldReferenceView soal kenapa struktur itu bikin konten naik ke
        // belakang nav bar.
        .background(Theme.color.surfaceMuted.ignoresSafeArea())
        .navigationTitle(viewModel.inspection.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!viewModel.isReadOnly)
        // Satu tombol "i" doang. Dulu ini menu titik-tiga (Add photos / Edit
        // condition / info) — dua aksi pertama dibuang: kondisi ruangan itu
        // masukan model, jadi ngubahnya DI report bikin angka prediksinya
        // berubah setelah user lihat hasilnya. Yang tersisa cuma penjelasan
        // gimana angkanya dihitung, dan buat satu aksi menu itu kelebihan.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRiskInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                // Kontrol chrome — warna label bawaan, bukan brand.
                .tint(.primary)
                .accessibilityLabel("How this is calculated")
            }
        }
        .sheet(isPresented: $showRiskInfo) {
            MoldRiskInfoSheet()
        }
        // Hapus foto dilakukan DARI preview-nya — user lihat dulu yang mau
        // dihapus, baru hapus. `item.index` dipegang di sini biar yang kehapus
        // persis foto yang lagi kebuka, bukan yang lagi kepilih di carousel.
        .fullScreenCover(item: $viewerItem) { item in
            FullScreenImageViewer(image: item.image, findings: item.findings) {
                viewModel.deletePhoto(
                    captureID: item.findings.first?.captureID,
                    plainPhotoOffset: item.plainPhotoOffset
                )
                photoIndex = min(photoIndex, max(photos.count - 1, 0))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    // MARK: - Foto

    /// Semua gambar yang mau ditampilin: foto yang ada temuannya dulu, terus
    /// foto yang nggak kedeteksi apa-apa.
    ///
    /// Sengaja NGGAK bikin tipe ber-UUID di sini. Ini computed property, jadi
    /// tiap kali view-nya di-render UUID-nya baru lagi — itu bikin identitas
    /// ForEach berubah terus dan selection TabView-nya nggak pernah nyantol.
    /// Indeks dipakai sebagai identitas, dan itu aman karena daftar ini cuma
    /// berubah lewat aksi eksplisit (tambah/hapus foto).
    /// Temuan DIKELOMPOKKAN per jepretan (`captureID`), jadi satu foto yang
    /// isinya beberapa titik jamur muncul sekali dengan beberapa kotak — bukan
    /// berkali-kali dengan satu kotak masing-masing.
    private var photos: [ReportPhoto] {
        var grouped: [UUID: [Finding]] = [:]
        var order: [UUID] = []
        for finding in viewModel.inspection.findings {
            if grouped[finding.captureID] == nil { order.append(finding.captureID) }
            grouped[finding.captureID, default: []].append(finding)
        }

        let withFindings = order.compactMap { captureID -> ReportPhoto? in
            guard let findings = grouped[captureID], let first = findings.first else { return nil }
            return ReportPhoto(image: first.frameImage, findings: findings, plainPhotoOffset: nil)
        }
        let plain = viewModel.inspection.capturedPhotos.enumerated().map { offset, image in
            ReportPhoto(image: image, findings: [], plainPhotoOffset: offset)
        }
        return withFindings + plain
    }

    @ViewBuilder
    private var photoStack: some View {
        if photos.isEmpty {
            emptyPhotoCard
        } else {
            // Geser + titik halaman, itu aja. Panah kiri/kanan dan tumpukan
            // foto di belakang dibuang: dua-duanya nambah chrome yang bikin
            // bingung (panah "maju" tapi kartunya gerak ke kiri), padahal galeri
            // foto di iOS emang polanya geser. Yang di-loop indeksnya, bukan
            // fotonya — `photoCard` butuh tau posisinya buat preview & hapus.
            VStack() {
                // Tingginya IKUT lebar halaman, bukan angka tetap — kartunya
                // harus persegi. Lebar halaman = lebar carousel dikurangi
                // intipan halaman sebelah, jadi tingginya dihitung dari situ.
                PagedCarousel(
                    items: Array(photos.indices),
                    peek: peekWidth,
                    spacing: 10,
                    index: $photoIndex
                ) { i in
                    photoCard(photos[i])
                }
                .frame(height: squarePageSide)

                if photos.count > 1 {
                    PageDots(count: photos.count, index: photoIndex)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    /// User yang bilang "nggak ada jamur keliatan" nggak pernah lewat kamera,
    /// jadi laporannya emang nggak punya foto — itu hasil yang normal, bukan
    /// kekurangan. Dulu di sini ada ikon + tombol "Add photos", dan itu kebaca
    /// kayak laporannya belum selesai. Sekarang yang muncul ilustrasi "no mold"
    /// yang sama persis dengan yang dipakai kartu ruangan.
    private var emptyPhotoCard: some View {
        Image("NoMoldPlaceholder")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(24)
            .frame(width: squarePageSide, height: squarePageSide)
            .background(
                Theme.color.card,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .accessibilityLabel("No mold found in this room")
    }

    private var peekWidth: CGFloat { photos.count > 1 ? 24 : 0 }

    /// Sisi kartu foto persegi = lebar satu halaman carousel.
    private var squarePageSide: CGFloat {
        max(contentWidth - peekWidth, 1)
    }

    /// Kartu foto PERSEGI, dan crop-nya NGIKUTIN jamurnya.
    ///
    /// Cara kerjanya: gambar dibesarkan sampai nutup penuh kotak (aspect-fill),
    /// lalu digeser supaya titik tengah semua temuan jatuh di tengah kotak —
    /// jadi kalau jamurnya di bawah, yang kepotong bagian atasnya, bukan
    /// jamurnya. Geserannya dijepit (`clamped`) supaya nggak pernah nongol
    /// bidang kosong di tepi.
    ///
    /// Kotak deteksi ditaruh DI DALAM ZStack yang ukurannya sama dengan gambar
    /// yang udah dibesarkan, jadi kotaknya ikut kegeser sendiri — nggak perlu
    /// ngitung ulang koordinatnya.
    private func photoCard(_ photo: ReportPhoto) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let imageAspect = photo.image.size.width / max(photo.image.size.height, 1)
            let scaledWidth = imageAspect >= 1 ? side * imageAspect : side
            let scaledHeight = imageAspect >= 1 ? side : side / imageAspect

            let focus = photo.moldFocus
            let maxOffsetX = max(0, (scaledWidth - side) / 2)
            let maxOffsetY = max(0, (scaledHeight - side) / 2)
            let offsetX = min(max((0.5 - focus.x) * scaledWidth, -maxOffsetX), maxOffsetX)
            let offsetY = min(max((0.5 - focus.y) * scaledHeight, -maxOffsetY), maxOffsetY)

            ZStack {
                Image(uiImage: photo.image)
                    .resizable()

                ForEach(photo.findings) { finding in
                    MoldDetectionBox(boundingBox: finding.boundingBox)
                }
            }
            .frame(width: scaledWidth, height: scaledHeight)
            .offset(x: offsetX, y: offsetY)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onTapGesture {
            viewerItem = ImageViewerItem(
                image: photo.image,
                findings: photo.findings,
                plainPhotoOffset: photo.plainPhotoOffset
            )
        }
    }

    // MARK: - Kartu

    /// Kartu prediksi: label kecil di atas, angka besar berwarna, chevron ke
    /// detail. Satu kartu penuh bisa ditap.
    /// NavigationLink, bukan sheet — desainnya (1339:7649) punya chevron back,
    /// jadi halaman detailnya di-push. Pakai bentuk closure biar nggak perlu
    /// nambah tipe ke NavigationPath di dua parent stack yang beda.
    private var predictionCard: some View {
        NavigationLink {
            RiskPredictionDetailSheet(viewModel: viewModel)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mold Growth Risk Prediction")
                        .font(Theme.font.cardLabel)
                        .foregroundStyle(Theme.color.textMuted)

                    Text(viewModel.riskRateText)
                        .font(Theme.font.statValue)
                        .foregroundStyle(viewModel.riskClassColor)
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.color.textMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.color.card,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var healthRiskCard: some View {
        bulletCard(
            title: "Potential Health Risk",
            items: viewModel.healthRisks,
            iconBackground: Theme.color.iconHealthBackground
        ) {
            // Hati + garis EKG, disusun dari dua SF Symbol — lihat
            // HeartbeatSymbol buat alasannya (nggak ada glyph gabungan bawaan).
            HeartbeatSymbol(size: 27)
                .foregroundStyle(Theme.color.iconHealthForeground)
        }
    }

    private var recommendationsCard: some View {
        bulletCard(
            title: "Recommendations",
            items: viewModel.recommendations,
            iconBackground: Theme.color.iconAdviceBackground
        ) {
            // `.fill` biar bobotnya seimbang sama `lungs.fill` di kartu atasnya
            // — versi outline kelihatan lebih tipis di sebelahnya.
            Image(systemName: "house.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.color.iconAdviceForeground)
        }
    }

    /// Kartu putih: tile ikon 49pt di kiri, label abu + daftar bullet di kanan.
    private func bulletCard<Icon: View>(
        title: String,
        items: [String],
        iconBackground: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            icon()
                .frame(width: 56, height: 56)
                .background(
                    iconBackground,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Theme.font.cardLabel)
                    .foregroundStyle(Theme.color.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(item)
                        }
                        .font(Theme.font.bulletItem)
                        .foregroundStyle(Theme.color.textPrimary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.color.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Bawah

    /// Figma: Discard (tombol kaca) + Save (kapsul gradient) berdampingan.
    /// Di mode read-only nggak ada yang perlu disimpan/dibuang, jadi barisnya
    /// nggak ditampilin sama sekali.
    @ViewBuilder
    private var bottomBar: some View {
        if !viewModel.isReadOnly {
            HStack(spacing: 16) {
                Button("Discard") {
                    if let onDiscard { onDiscard() } else { dismiss() }
                }
                .buttonStyle(.pillSecondary)

                Button("Save") {
                    viewModel.save()
                    onSaved?()
                }
                .buttonStyle(.pillProminent)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Model tampilan

/// Sengaja NGGAK `Identifiable` — daftarnya dibangun ulang tiap render, jadi
/// id apa pun yang di-generate di sini bakal berubah terus dan bikin ForEach
/// kehilangan identitas. Yang dipakai indeks.
private struct ReportPhoto {
    let image: UIImage
    /// Semua temuan di foto INI. Bisa lebih dari satu, karena satu jepretan
    /// bisa ngandung beberapa titik jamur.
    let findings: [Finding]
    /// Posisi di `capturedPhotos` buat foto tanpa temuan; `nil` kalau punya.
    let plainPhotoOffset: Int?

    /// Titik (ternormalisasi, origin kiri-atas) yang harus kelihatan waktu
    /// fotonya dipotong jadi persegi.
    ///
    /// Diambil dari tengah GABUNGAN semua kotak temuan, bukan cuma yang
    /// pertama — foto dengan dua noda di sudut berlawanan kalau ngikutin satu
    /// noda doang bikin noda yang lain kepotong. Foto tanpa temuan jatuh ke
    /// tengah gambar, sama kayak crop biasa.
    var moldFocus: CGPoint {
        guard let first = findings.first else { return CGPoint(x: 0.5, y: 0.5) }
        let union = findings.dropFirst().reduce(first.boundingBox) { $0.union($1.boundingBox) }
        return CGPoint(x: union.midX, y: union.midY)
    }
}

/// Pembungkus `Identifiable` buat `fullScreenCover(item:)` — UIImage sendiri
/// nggak Identifiable, jadi nggak bisa dipakai langsung sebagai item.
struct ImageViewerItem: Identifiable {
    let id = UUID()
    let image: UIImage
    /// Kotak deteksi ikut dibawa ke preview — tanpa ini, foto yang di-zoom
    /// malah kehilangan penanda jamurnya, padahal itu justru yang mau dilihat
    /// lebih besar.
    let findings: [Finding]
    /// Buat foto TANPA temuan: posisinya di `capturedPhotos`. `nil` kalau foto
    /// ini punya temuan (yang itu dihapus lewat `captureID`).
    let plainPhotoOffset: Int?
}
