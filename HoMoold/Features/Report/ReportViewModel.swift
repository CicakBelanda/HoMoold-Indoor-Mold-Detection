//
//  ReportViewModel.swift
//  HoMoold
//

import Combine
import Foundation

@MainActor
final class ReportViewModel: ObservableObject {
    enum Source {
        /// Hasil analisis baru, nempel ke kos yang SUDAH ADA — bisa langsung disimpan.
        case draftExisting(propertyID: UUID)
        /// Hasil analisis baru, kos BARU — belum ada nama/harga, jadi belum bisa disimpan
        /// di sini. Tombol Simpan lanjut ke NewReportInfoView.
        case pendingNaming
        /// Lihat ulang temuan yang sudah tersimpan — read-only.
        case saved(propertyID: UUID)
    }

    private let store: AppDataStore
    let source: Source
    let isReadOnly: Bool
    @Published var inspection: RoomInspection
    @Published var didSave = false

    init(store: AppDataStore, inspection: RoomInspection, source: Source, isReadOnly: Bool) {
        self.store = store
        self.inspection = inspection
        self.source = source
        self.isReadOnly = isReadOnly
    }

    var riskTitle: String {
        "Risiko Pertumbuhan Jamur \(inspection.riskLevel.labelID)"
    }

    var riskExplanation: String {
        "Skor ini dihitung dari tiga hal: kondisi kerusakan/lembap yang terlihat, seberapa baik ventilasi ruangan (jendela, AC, arah bukaan), dan kondisi cuaca daerah ini. Skor tinggi berarti ruangan berisiko lembap terus-menerus meskipun jamurnya belum kelihatan."
    }

    /// Satu paragraf dampak kesehatan (bukan tabel jangka pendek/panjang) —
    /// lebih gampang dibaca cepat pas lagi survei di lokasi.
    var healthImpactText: String {
        switch inspection.riskLevel {
        case .low:
            return "Risiko kesehatan masih rendah. Tetap perhatikan kalau mulai tercium bau apek atau muncul noda baru di kemudian hari."
        case .medium:
            return "Paparan lembap ringan bisa memicu bersin, hidung gatal, atau tenggorokan kering kalau kamu lama berada di ruangan ini."
        case .high:
            return "Paparan jamur bisa memicu batuk, iritasi, dan alergi, serta memperparah asma pada orang yang sensitif — apalagi kalau lembapnya terus-menerus."
        }
    }

    struct PreventionTip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
    }

    var preventionTips: [PreventionTip] {
        var tips: [PreventionTip] = []
        if inspection.ventilationWarning != nil {
            tips.append(PreventionTip(icon: "wind", label: "Perbaiki ventilasi ruangan"))
        }
        tips.append(PreventionTip(icon: "magnifyingglass", label: "Cari sumber lembapnya"))
        tips.append(PreventionTip(icon: "tshirt", label: "Jangan jemur baju di kamar ini"))
        tips.append(PreventionTip(icon: "arrow.left.and.right", label: "Geser furnitur dari dinding lembap"))
        if inspection.findings.contains(where: { $0.findingClass == .crack }) {
            tips.append(PreventionTip(icon: "bandage", label: "Cek riwayat retakan ke pemilik"))
        }
        tips.append(PreventionTip(icon: "person.fill.questionmark", label: "Tanya riwayat bocor ke pemilik"))
        return tips
    }

    func toggleReviewed(_ findingID: UUID) {
        guard let index = inspection.findings.firstIndex(where: { $0.id == findingID }) else { return }
        inspection.findings[index].isReviewed.toggle()
        if case .saved(let propertyID) = source {
            store.toggleReviewed(findingID: findingID, inRoom: inspection.id, ofProperty: propertyID)
        }
    }

    func save() {
        guard case .draftExisting(let propertyID) = source else { return }
        store.attachInspection(inspection, toExistingPropertyID: propertyID)
        store.lastSavedPropertyID = propertyID
        didSave = true
    }
}
