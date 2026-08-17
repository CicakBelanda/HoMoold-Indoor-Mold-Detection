//
//  ReportViewModel.swift
//  HoMoold
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class ReportViewModel: ObservableObject {
    enum Source {
        /// Hasil analisis baru, nempel ke rumah yang sudah ada — bisa langsung disimpan.
        /// `location` ikut disimpan ke properti (rumah baru yang belum punya lokasi).
        case draftExisting(propertyID: UUID, location: HomeLocation)
        /// Lihat ulang temuan yang sudah tersimpan — read-only.
        case saved(propertyID: UUID)
    }

    private let store: AppDataStore
    let source: Source
    let isReadOnly: Bool
    @Published var inspection: RoomInspection

    /// Prediksi risiko dari RiskClassifier (model). `nil` kalau cuaca gagal
    /// diambil (temperature/humidity kosong) — UI-nya nampilin "—".
    private let classifier: RiskClassifierService?

    init(store: AppDataStore, inspection: RoomInspection, source: Source, isReadOnly: Bool) {
        self.store = store
        self.inspection = inspection
        self.source = source
        self.isReadOnly = isReadOnly
        self.classifier = try? RiskClassifierService()
    }

    /// Output Risk_Class model ("Low"/"Medium"/"High") untuk kartu Risiko.
    var riskClass: String? {
        guard let t = inspection.temperature, let h = inspection.humidity else { return nil }
        return classifier?.predict(
            temperature: t, humidity: h,
            hasAC: inspection.hasAC, hasWindow: inspection.hasWindow,
            dampness: inspection.dampness, wallCrack: inspection.wallCrack,
            moldLevel: inspection.moldSeverityLevel
        )
    }

    /// Warna kartu risiko: Low=green, Medium=orange, High=red (fallback gray).
    var riskClassColor: Color {
        guard let risk = riskClass else { return .gray }
        switch risk.lowercased() {
        case "low": return .green
        case "medium": return .orange
        default: return .red
        }
    }

    var riskExplanation: String {
        "This score is calculated from the visible damage/moisture conditions and the weather in this area. A high score means the room is at risk of prolonged dampness even if the mold isn't visible yet."
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
            lines.append(inspection.findings.count == 1 ? "Mold stain at 1 spot" : "Mold stains at \(inspection.findings.count) spots")
        }
        if inspection.wallCrack {
            lines.append("There is a wall crack")
        }
        return lines.isEmpty ? "No prominent visual findings" : lines.joined(separator: "\n")
    }

    /// Faktor lingkungan yang berkontribusi ke risiko — disusun dari kondisi
    /// ruangan yang dilaporkan manual di ConditionFormView.
    var environmentalFactorsText: String {
        var lines: [String] = []
        if inspection.dampness {
            lines.append("High humidity in this room")
        }
        if !inspection.hasWindow {
            lines.append("Poor room ventilation")
        }
        return lines.isEmpty ? "No prominent environmental factors" : lines.joined(separator: "\n")
    }

    /// Satu paragraf dampak kesehatan (bukan tabel jangka pendek/panjang) —
    /// lebih gampang dibaca cepat pas lagi survei di lokasi.
    var healthImpactText: String {
        switch inspection.riskLevel {
        case .low:
            return "Health risk is still low. Keep an eye out in case a musty smell or new stains appear later."
        case .medium:
            return "Mild dampness exposure can trigger sneezing, an itchy nose, or a dry throat if you spend a lot of time in this room."
        case .high:
            return "Mold exposure can trigger coughing, irritation, and allergies, and worsen asthma in sensitive people — especially if the dampness is constant."
        }
    }

    struct PreventionTip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
    }

    var preventionTips: [PreventionTip] {
        var tips: [PreventionTip] = []
        tips.append(PreventionTip(icon: "magnifyingglass", label: "Find the source of the moisture"))
        tips.append(PreventionTip(icon: "tshirt", label: "Don't hang laundry to dry in this room"))
        tips.append(PreventionTip(icon: "arrow.left.and.right", label: "Move furniture away from damp walls"))
        if inspection.wallCrack {
            tips.append(PreventionTip(icon: "bandage", label: "Check the crack history with the owner"))
        }
        tips.append(PreventionTip(icon: "person.fill.questionmark", label: "Ask the owner about past leaks"))
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
