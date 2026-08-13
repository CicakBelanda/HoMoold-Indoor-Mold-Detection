//
//  ReportView.swift
//  HoMoold
//

import SwiftUI

struct ReportView: View {
    @StateObject private var viewModel: ReportViewModel
    @State private var viewerItem: ImageViewerItem?
    @State private var carouselID: String?
    @Environment(\.dismiss) private var dismiss
    private var onSaved: (() -> Void)?

    /// Mode draft: hasil analisis baru, nempel ke rumah yang sudah ada — tombol
    /// Simpan langsung menyimpan (`location` cuma beneran ditulis kalau
    /// rumahnya belum punya lokasi, lihat AppDataStore.attachInspection).
    init(store: AppDataStore, draftInspection: RoomInspection, existingPropertyID: UUID, location: HomeLocation, onSaved: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: draftInspection,
            source: .draftExisting(propertyID: existingPropertyID, location: location),
            isReadOnly: false
        ))
        self.onSaved = onSaved
    }

    /// Mode "saved": lihat ulang temuan yang sudah tersimpan, read-only (tanpa tombol Simpan).
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
            VStack(alignment: .leading, spacing: 16) {
                carousel

                statsRow
                    .padding(.horizontal, 20)

                infoCard(
                    icon: "heart.fill", iconColor: .pink, iconBg: .pink.opacity(0.15),
                    title: "Potensi Dampak Kesehatan", text: viewModel.healthImpactText
                )
                .padding(.horizontal, 20)

                infoCard(
                    icon: "eye.fill", iconColor: .blue, iconBg: .blue.opacity(0.12),
                    title: "Temuan Visual", text: viewModel.visualFindingsText
                )
                .padding(.horizontal, 20)

                infoCard(
                    icon: "house.fill", iconColor: .purple, iconBg: .purple.opacity(0.12),
                    title: "Faktor Lingkungan", text: viewModel.environmentalFactorsText
                )
                .padding(.horizontal, 20)

                preventionSection
                    .padding(.horizontal, 20)

                Color.clear.frame(height: 12)
            }
            .padding(.top, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(viewModel.inspection.roomType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!viewModel.isReadOnly)
        .fullScreenCover(item: $viewerItem) { item in
            FullScreenImageViewer(image: item.image)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if let finding = currentFinding {
                    Button(finding.isReviewed ? "Sudah Dilabel" : "Label") {
                        viewModel.toggleReviewed(finding.id)
                    }
                    .buttonStyle(.pillSecondary)
                }
                if !viewModel.isReadOnly {
                    Button("Simpan") {
                        viewModel.save()
                        onSaved?()
                    }
                    .buttonStyle(.pillProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(.bar)
        }
    }

    /// Satu kartu carousel — foto yang ada deteksi jamur (kotak + label), atau
    /// foto yang diambil tapi 0 jamur kedeteksi (polos, gak ada kotak).
    private enum CarouselItem: Identifiable {
        case finding(Finding)
        case photo(UIImage, Int)

        var id: String {
            switch self {
            case .finding(let f): return "f-\(f.id.uuidString)"
            case .photo(_, let index): return "p-\(index)"
            }
        }
    }

    private var carouselItems: [CarouselItem] {
        viewModel.inspection.findings.map { .finding($0) }
            + viewModel.inspection.capturedPhotos.enumerated().map { .photo($0.element, $0.offset) }
    }

    private var currentFinding: Finding? {
        let item: CarouselItem?
        if let carouselID {
            item = carouselItems.first { $0.id == carouselID }
        } else {
            item = carouselItems.first
        }
        if case .finding(let finding) = item { return finding }
        return nil
    }

    // MARK: - Carousel

    private var carousel: some View {
        Group {
            if carouselItems.isEmpty {
                ZStack {
                    Image(uiImage: viewModel.inspection.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onTapGesture {
                            viewerItem = ImageViewerItem(image: viewModel.inspection.thumbnail)
                        }
                    LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .bottom, endPoint: .center)
                        .allowsHitTesting(false)
                    VStack {
                        Spacer()
                        Text("Tidak ada tanda pra-jamur yang terdeteksi jelas")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.bottom, 16)
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(carouselItems) { item in
                            carouselCard(item)
                                .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 14)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $carouselID)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .frame(height: 320)
            }
        }
    }

    @ViewBuilder
    private func carouselCard(_ item: CarouselItem) -> some View {
        switch item {
        case .finding(let finding):
            findingCard(finding)
        case .photo(let image, _):
            photoCard(image)
        }
    }

    private func findingCard(_ finding: Finding) -> some View {
        ZStack {
            Image(uiImage: finding.frameImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .onTapGesture {
                    viewerItem = ImageViewerItem(image: finding.frameImage)
                }

            BoundingBoxOverlay(findingClass: finding.findingClass, boundingBox: finding.boundingBox)
                .allowsHitTesting(false)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 2, y: 4)
    }

    /// Foto yang diambil tapi gak ada jamur kedeteksi — tanpa bounding box.
    private func photoCard(_ image: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .onTapGesture {
                    viewerItem = ImageViewerItem(image: image)
                }

            Text("Gak ada jamur yang kedeteksi di foto ini")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.bottom, 14)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 2, y: 4)
    }

    // MARK: - Stats

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Baris atas: Keparahan Jamur + Luas (50:50).
            HStack(alignment: .top, spacing: 12) {
                // KARTU KEPARAHAN JAMUR — dihitung dari total luas jamur
                // (LiDAR), lihat MoldSeverity. Nanti Risk_Class dari model
                // dipakai buat kartu Risiko di bawah.
                let severity = MoldSeverity.severity(fromAreaCM2: viewModel.inspection.totalAreaCM2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keparahan Jamur")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(severity.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(severity.color)
                        Spacer(minLength: 0)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(severity.color)
                            .frame(width: 40, height: 40)
                            .background(severity.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let areaText = viewModel.totalAreaText {
                    VStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(areaText)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .frame(width: 100)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            // Baris bawah: Risiko Pertumbuhan Jamur (lebar penuh).
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Risiko Pertumbuhan Jamur")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    InfoSheetButton(accessibilityLabel: "Penjelasan metodologi skor risiko") {
                        MoldRiskInfoSheet(explanation: viewModel.riskExplanation)
                    }
                }
                HStack {
                    Text(viewModel.riskClass ?? "—")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(viewModel.riskClassColor)
                    Spacer(minLength: 0)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.riskClassColor)
                        .frame(width: 40, height: 40)
                        .background(viewModel.riskClassColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Info card

    private func infoCard(icon: String, iconColor: Color, iconBg: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Prevention

    private var preventionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cara Mencegah / Menangani")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.preventionTips) { tip in
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: tip.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        Text(tip.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .frame(minHeight: 96, alignment: .topLeading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct ImageViewerItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    let finding = Finding(
        boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.4, height: 0.35),
        frameImage: PlaceholderImageFactory.findingFrame(for: .bedroom, seed: 1, stainAt: CGPoint(x: 0.4, y: 0.35), findingClass: .mold),
        findingClass: .mold, locationNote: "sudut plafon dekat jendela", areaCM2: 340
    )
    let room = RoomInspection(
        roomType: .bedroom, riskLevel: .medium, riskScore: 52, findings: [finding],
        hasAC: false, hasWindow: true, dampness: true, wallCrack: true, date: Date()
    )
    let property = KosProperty(
        name: "Kos Contoh", location: HomeLocation(region: "Banten", city: "Tangerang", district: "Kec. Cisauk"),
        price: 850_000, rooms: [room]
    )
    let store = AppDataStore(properties: [property])
    return NavigationStack {
        ReportView(store: store, propertyID: property.id, roomID: room.id)
    }
}
