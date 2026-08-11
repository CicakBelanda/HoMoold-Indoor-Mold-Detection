//
//  ReportView.swift
//  HoMoold
//

import SwiftUI

struct ReportView: View {
    @StateObject private var viewModel: ReportViewModel
    @State private var showRiskInfo = false
    @State private var viewerItem: ImageViewerItem?
    @Environment(\.dismiss) private var dismiss
    private var onSaved: (() -> Void)?
    private var onContinueToNaming: (() -> Void)?

    /// Mode "kos sudah ada": hasil analisis baru, tapi nempel ke properti yang sudah
    /// diketahui — tombol Simpan langsung menyimpan.
    init(store: AppDataStore, draftInspection: RoomInspection, existingPropertyID: UUID, onSaved: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: draftInspection,
            source: .draftExisting(propertyID: existingPropertyID),
            isReadOnly: false
        ))
        self.onSaved = onSaved
        self.onContinueToNaming = nil
    }

    /// Mode "kos baru": hasil analisis baru, belum ada nama/harga — tombol Simpan
    /// lanjut ke halaman isi nama & harga, bukan menyimpan di sini.
    init(store: AppDataStore, draftInspection: RoomInspection, onContinueToNaming: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: draftInspection,
            source: .pendingNaming,
            isReadOnly: false
        ))
        self.onSaved = nil
        self.onContinueToNaming = onContinueToNaming
    }

    /// Mode "saved": lihat ulang temuan yang sudah tersimpan, read-only (tanpa tombol Simpan).
    init(store: AppDataStore, propertyID: UUID, roomID: UUID) {
        let existing = store.properties.first(where: { $0.id == propertyID })?.rooms.first(where: { $0.id == roomID })
        let fallback = RoomInspection(roomType: .bedroom, riskLevel: .low, riskScore: 0, findings: [], videoURL: nil, date: Date())
        _viewModel = StateObject(wrappedValue: ReportViewModel(
            store: store,
            inspection: existing ?? fallback,
            source: .saved(propertyID: propertyID),
            isReadOnly: true
        ))
        self.onSaved = nil
        self.onContinueToNaming = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                carousel

                HStack(spacing: 6) {
                    (Text("Risiko Pertumbuhan Jamur ").foregroundStyle(.primary)
                        + Text(viewModel.inspection.riskLevel.labelID).foregroundStyle(viewModel.inspection.riskLevel.color))
                        .font(.title2.weight(.bold))
                    Button {
                        showRiskInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Penjelasan metodologi skor risiko")
                }
                .padding(.horizontal, 20)

                detectionChecklistSection
                    .padding(.horizontal, 20)

                healthImpactSection
                    .padding(.horizontal, 20)

                preventionSection
                    .padding(.horizontal, 20)

                Color.clear.frame(height: viewModel.isReadOnly ? 12 : 90)
            }
            .padding(.top, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(viewModel.inspection.roomType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!viewModel.isReadOnly)
        .sheet(isPresented: $showRiskInfo) {
            MoldRiskInfoSheet(explanation: viewModel.riskExplanation)
        }
        .fullScreenCover(item: $viewerItem) { item in
            FullScreenImageViewer(image: item.image)
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isReadOnly {
                Button("Simpan") {
                    switch viewModel.source {
                    case .draftExisting:
                        viewModel.save()
                        onSaved?()
                    case .pendingNaming:
                        onContinueToNaming?()
                    case .saved:
                        break
                    }
                }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
    }

    // MARK: - Carousel

    private var carousel: some View {
        Group {
            if viewModel.inspection.findings.isEmpty {
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
                .frame(height: 360)
                .clipped()
            } else {
                TabView {
                    ForEach(viewModel.inspection.findings) { finding in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: finding.frameImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 360)
                                .clipped()
                                .onTapGesture {
                                    viewerItem = ImageViewerItem(image: finding.frameImage)
                                }

                            BoundingBoxOverlay(findingClass: finding.findingClass, boundingBox: finding.boundingBox)
                                .frame(height: 360)
                                .allowsHitTesting(false)

                            Button {
                                viewModel.toggleReviewed(finding.id)
                            } label: {
                                Image(systemName: finding.isReviewed ? "checkmark.circle.fill" : "checkmark.circle")
                                    .font(.title)
                                    .foregroundStyle(.white, Color.accentColor)
                                    .background(Circle().fill(.white).padding(2))
                            }
                            .accessibilityLabel(finding.isReviewed ? "Sudah ditinjau" : "Tandai sudah ditinjau")
                            .padding(14)
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 360)
            }
        }
    }

    // MARK: - Sections

    private var detectionChecklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ringkasan Deteksi")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.inspection.detectionChecklist.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.label)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(item.isPresent ? "Ya" : "Tidak")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.isPresent ? Color.accentColor : .secondary)
                    }
                    .padding(.vertical, 10)

                    if index < viewModel.inspection.detectionChecklist.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var healthImpactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Potensi Dampak Kesehatan")
                .font(.headline)

            Text(viewModel.healthImpactText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

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
    let store = AppDataStore()
    let property = store.properties[0]
    return NavigationStack {
        ReportView(store: store, propertyID: property.id, roomID: property.rooms[0].id)
    }
}
