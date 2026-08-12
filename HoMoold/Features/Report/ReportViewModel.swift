//
//  ReportViewModel.swift
//  HoMoold
//

import Combine
import Foundation

@MainActor
final class ReportViewModel: ObservableObject {
    enum Source {
        /// Hasil analisis baru, nempel ke rumah yang sudah ada — bisa langsung disimpan.
        /// `location` ikut disimpan ke properti (rumah baru yang belum punya lokasi).
        case draftExisting(propertyID: UUID, location: KosLocation)
        /// Lihat ulang temuan yang sudah tersimpan — read-only.
        case saved(propertyID: UUID)
    }

    private let store: AppDataStore
    let source: Source
    let isReadOnly: Bool
    @Published var inspection: RoomInspection

    init(store: AppDataStore, inspection: RoomInspection, source: Source, isReadOnly: Bool) {
        self.store = store
        self.inspection = inspection
        self.source = source
        self.isReadOnly = isReadOnly
    }

    var riskExplanation: String {
        "Skor ini dihitung dari kondisi kerusakan/lembap yang terlihat dan kondisi cuaca daerah ini. Skor tinggi berarti ruangan berisiko lembap terus-menerus meskipun jamurnya belum kelihatan."
    }

    /// Total luas jamur yang kedeteksi, diformat "0,96 m²" — nil kalau gak ada
    /// satu pun temuan yang berhasil diukur (LiDAR gagal baca depth-nya).
    var totalAreaText: String? {
        guard let cm2 = inspection.totalAreaCM2 else { return nil }
        let m2 = cm2 / 10_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: m2)) ?? String(format: "%.2f", m2)
        return "\(formatted) m²"
    }

    /// Ringkasan temuan visual — cuma kelas "mold" yang dideteksi model saat
    /// ini, jadi disusun dari jumlah temuan + kondisi retak dinding yang
    /// dilaporkan manual (bukan daftar per-kelas seperti dulu).
    var visualFindingsText: String {
        var lines: [String] = []
        if !inspection.findings.isEmpty {
            lines.append(inspection.findings.count == 1 ? "Noda jamur di 1 titik" : "Noda jamur di \(inspection.findings.count) titik")
        }
        if inspection.wallCrack {
            lines.append("Ada retak dinding")
        }
        return lines.isEmpty ? "Gak ada temuan visual yang mencolok" : lines.joined(separator: "\n")
    }

    /// Faktor lingkungan yang berkontribusi ke risiko — disusun dari kondisi
    /// ruangan yang dilaporkan manual di ConditionFormView.
    var environmentalFactorsText: String {
        var lines: [String] = []
        if inspection.dampness {
            lines.append("Kelembapan tinggi di ruangan ini")
        }
        if !inspection.hasWindow {
            lines.append("Ventilasi ruang kurang baik")
        }
        return lines.isEmpty ? "Gak ada faktor lingkungan yang mencolok" : lines.joined(separator: "\n")
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
        tips.append(PreventionTip(icon: "magnifyingglass", label: "Cari sumber lembapnya"))
        tips.append(PreventionTip(icon: "tshirt", label: "Jangan jemur baju di kamar ini"))
        tips.append(PreventionTip(icon: "arrow.left.and.right", label: "Geser furnitur dari dinding lembap"))
        if inspection.wallCrack {
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
        guard case .draftExisting(let propertyID, let location) = source else { return }
        store.attachInspection(inspection, toExistingPropertyID: propertyID, location: location)
        store.lastSavedPropertyID = propertyID
    }
}
