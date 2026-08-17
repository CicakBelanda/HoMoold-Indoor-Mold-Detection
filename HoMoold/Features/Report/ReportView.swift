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
    @State private var showEditCondition = false
    @State private var addPhotoSession: AddPhotoSession?
    @Environment(\.dismiss) private var dismiss
    private var onSaved: (() -> Void)?

    /// Mode draft: hasil analisis baru, nempel ke rumah yang sudah ada — tombol
    /// Save langsung menyimpan (`location` cuma beneran ditulis kalau rumahnya
    /// belum punya lokasi, lihat AppDataStore.attachInspection).
    @MainActor
    init(store: AppDataStore, draftInspection: RoomInspection, existingPropertyID: UUID, location: HomeLocation, onSaved: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: draftInspection,
            source: .draftExisting(propertyID: existingPropertyID, location: location),
            isReadOnly: false
        ))
        self.onSaved = onSaved
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
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                photoStack

                predictionCard
                healthRiskCard
                recommendationsCard
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        // Latar lewat `.background`, bukan sibling ZStack — lihat catatan di
        // MoldReferenceView soal kenapa struktur itu bikin konten naik ke
        // belakang nav bar.
        .background(Theme.color.surfaceMuted.ignoresSafeArea())
        .navigationTitle(viewModel.inspection.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!viewModel.isReadOnly)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        startAddingPhotos()
                    } label: {
                        Label("Add photos", systemImage: "camera")
                    }

                    Button {
                        showEditCondition = true
                    } label: {
                        Label("Edit condition", systemImage: "checklist")
                    }

                    Divider()

                    Button {
                        showRiskInfo = true
                    } label: {
                        Label("How this is calculated", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                // Kontrol chrome — warna label bawaan, bukan brand.
                .tint(.primary)
                .accessibilityLabel("Report options")
            }
        }
        .sheet(isPresented: $showRiskInfo) {
            MoldRiskInfoSheet()
        }
        // Sheet yang sama kayak di daftar ruangan, tapi hasilnya lewat view
        // model — di sini kondisi yang berubah harus nge-trigger hitung ulang
        // prediksi, bukan cuma disimpen.
        .sheet(isPresented: $showEditCondition) {
            EditRoomConditionSheet(room: viewModel.inspection) { hasAC, hasWindow, dampness, wallCrack in
                viewModel.updateConditions(
                    hasAC: hasAC, hasWindow: hasWindow,
                    dampness: dampness, wallCrack: wallCrack
                )
            }
        }
        // Kamera dibuka lagi dari sini buat nambah jepretan yang kelupaan.
        // `onFinish` bikin CaptureView balik ke sini, bukan maju ke loading.
        //
        // Pakai `item:`, BUKAN `isPresented:` + `if let`. Dengan isPresented,
        // flag-nya bisa nyala sepersekian detik sebelum flow-nya keisi, dan
        // cover-nya kebuka dengan konten kosong.
        .fullScreenCover(item: $addPhotoSession) { session in
            CaptureView(flow: session.flow) {
                viewModel.appendPhotos(
                    findings: session.flow.capturedFindings,
                    photos: session.flow.capturedPhotos
                )
                addPhotoSession = nil
            }
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
            VStack(spacing: 12) {
                PagedCarousel(
                    items: Array(photos.indices),
                    peek: photos.count > 1 ? 24 : 0,
                    spacing: 10,
                    index: $photoIndex
                ) { i in
                    photoCard(photos[i], at: i)
                }
                .frame(height: 290)

                if photos.count > 1 {
                    PageDots(count: photos.count, index: photoIndex)
                }
            }
        }
    }

    private var emptyPhotoCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Theme.color.card)
            .frame(height: 300)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.color.textSecondary)
                    Text("No photos yet")
                        .font(Theme.font.subheadline)
                        .foregroundStyle(Theme.color.textSecondary)

                    Button("Add photos") { startAddingPhotos() }
                        .font(Theme.font.headline)
                        .padding(.top, 2)
                }
            }
    }

    private func photoCard(_ photo: ReportPhoto, at index: Int) -> some View {
        // Gambar + kotak deteksi dibungkus ZStack ber-aspect-ratio sama dengan
        // gambarnya, biar koordinat ternormalisasi kotaknya nempel presisi.
        ZStack {
            Image(uiImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)

            ForEach(photo.findings) { finding in
                MoldDetectionBox(boundingBox: finding.boundingBox)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            viewerItem = ImageViewerItem(
                image: photo.image,
                findings: photo.findings,
                plainPhotoOffset: photo.plainPhotoOffset
            )
        }
    }

    /// Bikin flow state kosong yang cuma dipakai sebagai wadah hasil jepretan,
    /// terus buka kamera. Tipe & nama ruangan diikutin dari inspeksi yang lagi
    /// dibuka biar konsisten.
    private func startAddingPhotos() {
        let flow = InspectionFlowState(existingProperty: viewModel.owningProperty)
        flow.roomName = viewModel.inspection.name
        flow.roomType = viewModel.inspection.roomType
        addPhotoSession = AddPhotoSession(flow: flow)
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
                Button("Discard") { dismiss() }
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
}

/// Pembungkus `Identifiable` buat `fullScreenCover(item:)` — sesi "nambah foto"
/// yang bawa flow state sementaranya.
private struct AddPhotoSession: Identifiable {
    let id = UUID()
    let flow: InspectionFlowState
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
