//
//  ReportViewModel.swift
//  HoMoold
//

import Combine
import UIKit
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

    /// Cache hasil model. Double-optional disengaja: `nil` = belum pernah
    /// dihitung, `.some(nil)` = udah dihitung dan hasilnya emang nggak ada.
    ///
    /// Dulu ini `lazy var`, tapi lazy nggak bisa di-invalidate — padahal
    /// nambah/ngapus foto ngubah `moldSeverityLevel`, yang jadi salah satu input
    /// model. Efeknya prediksinya nyangkut di nilai lama.
    private var cachedPrediction: RiskClassifierService.Prediction??

    private var prediction: RiskClassifierService.Prediction? {
        if let cachedPrediction { return cachedPrediction }
        let value = computePrediction()
        cachedPrediction = value
        return value
    }

    /// Nggak ada lagi `guard` buat cuaca nil di sini.
    ///
    /// Dulu cuaca yang gagal keambil bikin seluruh laporan nulis "Unavailable",
    /// padahal enam input lainnya lengkap — dan enam itu justru yang diamati
    /// langsung sama user. Sekarang cuacanya jatuh ke `WeatherDefaults` dan
    /// laporannya ditandai `isWeatherEstimated`.
    private func computePrediction() -> RiskClassifierService.Prediction? {
        return classifier?.predictDetailed(
            temperature: inspection.effectiveTemperature,
            humidity: inspection.effectiveHumidity,
            hasAC: inspection.hasAC, hasWindow: inspection.hasWindow,
            dampness: inspection.dampness, wallCrack: inspection.wallCrack,
            moldLevel: inspection.moldSeverityLevel
        )
    }

    /// Output Risk_Class model ("Low"/"Medium"/"High") untuk kartu Risiko.
    var riskClass: String? { prediction?.riskClass }

    /// Keyakinan model, 0–1. `nil` kalau cuaca nggak keambil atau model nggak
    /// ngasih probabilitas.
    var confidence: Double? { prediction?.confidence }

    /// Sebaran peluang tiap level, diurut dari yang paling besar.
    ///
    /// Ditampilin apa adanya karena angka tunggal "93,94%" itu gampang disalah
    /// artiin sebagai akumulasi semua level. Padahal bukan: totalnya SELALU
    /// 100%, dan yang ditampilin di atas cuma porsi level yang menang.
    var confidenceBreakdown: [(label: String, value: Double)] {
        guard let probabilities = prediction?.probabilities, !probabilities.isEmpty else { return [] }
        let order = ["High": 0, "Medium": 1, "Low": 2]
        return probabilities
            .map { (label: $0.key, value: $0.value) }
            .sorted { (order[$0.label] ?? 99) < (order[$1.label] ?? 99) }
    }

    /// Keyakinan diformat "67,67%" sesuai desain (pakai koma desimal).
    var confidenceText: String? {
        guard let confidence else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        let value = formatter.string(from: NSNumber(value: confidence * 100)) ?? "—"
        return "\(value)%"
    }

    /// Angka PERSIS yang dikirim ke RiskClassifier.
    ///
    /// Ditampilin ke user karena prediksinya gampang kelihatan "selalu High"
    /// tanpa alasan yang jelas. Begitu input-nya keliatan, biasanya ketahuan
    /// penyebabnya: `RH_out` itu kelembapan LUAR RUANGAN dari Open-Meteo, dan
    /// di iklim tropis angkanya jarang di bawah 75%. Nilai setinggi itu bikin
    /// satu input mendominasi hasil, seberapa pun kondisi ruangannya bagus.
    var modelInputs: [(label: String, value: String)] {
        let t = inspection.effectiveTemperature
        let h = inspection.effectiveHumidity
        // Ditandai "(estimated)" kalau angkanya dari WeatherDefaults, bukan dari
        // Open-Meteo — biar user nggak salah baca tebakan sebagai ukuran.
        let suffix = inspection.isWeatherEstimated ? ", estimated" : ""
        return [
            ("Temperature (outdoor\(suffix))", String(format: "%.0f °C", t)),
            // +5 itu offset yang dipasang di RiskClassifierService buat nebak
            // selisih indoor vs outdoor. Ditampilin apa adanya, bukan angka
            // mentahnya, supaya cocok sama yang beneran masuk ke model.
            ("Humidity (outdoor +5\(suffix))", String(format: "%.0f %%", h + 5)),
            ("Air conditioner", inspection.hasAC ? "Yes" : "No"),
            ("Window", inspection.hasWindow ? "Yes" : "No"),
            ("Dampness", inspection.dampness ? "Yes" : "No"),
            ("Wall crack", inspection.wallCrack ? "Yes" : "No"),
            ("Mold level", "\(inspection.moldSeverityLevel) of 3"),
        ]
    }

    /// Level keparahan jamur sebagai teks, buat kartu "Mold Severity".
    var moldSeverityText: String {
        MoldSeverity.label(forLevel: inspection.moldSeverityLevel)
    }

    /// Warna kartu risiko — lewat Theme biar konsisten sama pil risiko di kartu
    /// ruangan. Gray = prediksi nggak tersedia (cuaca gagal diambil).
    var riskClassColor: Color {
        guard let risk = riskClass else { return Theme.color.textSecondary }
        switch risk.lowercased() {
        case "low": return Theme.color.riskLow
        case "medium": return Theme.color.riskMedium
        default: return Theme.color.riskHigh
        }
    }

    /// Peringatan kalau prediksi ini jalan pakai cuaca tebakan, bukan cuaca
    /// asli di lokasi rumahnya. `nil` = cuacanya beneran keambil.
    ///
    /// WAJIB ditampilin di mana pun prediksinya dipajang. Angka yang keluar dari
    /// model kelihatan sama persis meyakinkannya entah input cuacanya diukur
    /// atau ditebak — satu-satunya yang bisa mbedain itu catatan ini.
    var estimatedWeatherNote: String? {
        guard inspection.isWeatherEstimated else { return nil }
        return String(
            format: "Local weather wasn't available during this inspection, so the prediction uses Indonesia's typical outdoor climate (%.0f°C, %.0f%% humidity). Treat the result as a rough estimate.",
            WeatherDefaults.temperature, WeatherDefaults.humidity
        )
    }

    /// Teks besar di kartu prediksi, mis. "Medium Rate" (Figma 1339:7594).
    var riskRateText: String {
        guard let risk = riskClass else { return "Unavailable" }
        return "\(risk) Risk"
    }

    /// Dampak kesehatan sebagai DAFTAR, bukan paragraf.
    ///
    /// Sebelumnya ini satu paragraf panjang, dan itu yang bikin Report-nya
    /// "full tulisan semua". Desainnya (Figma 1339:7594) minta bullet — jauh
    /// lebih kebaca buat orang yang lagi keliling ngecek rumah.
    var healthRisks: [String] {
        switch inspection.riskLevel {
        case .low:
            return ["Mild musty smell", "Occasional sneezing"]
        case .medium:
            return ["Sneezing", "Coughing", "Blocked nose", "Itchy eyes"]
        case .high:
            return ["Persistent coughing", "Skin and eye irritation", "Allergy flare-ups", "Worsening asthma"]
        }
    }

    /// Rekomendasi sebagai daftar — sama alasannya kayak `healthRisks`.
    var recommendations: [String] {
        var items = ["Deep clean the mold spots"]
        if inspection.wallCrack {
            items.append("Patch the leak in the wall")
        }
        if !inspection.hasWindow {
            items.append("Improve airflow in this room")
        }
        if inspection.dampness {
            items.append("Don't dry laundry indoors here")
        }
        return items
    }


    /// Berapa temuan yang luasnya BERHASIL diukur, dari total temuan.
    ///
    /// Dua angka ini penting ditampilin: `totalAreaCM2` itu penjumlahan
    /// `compactMap(\.areaCM2)`, jadi temuan yang gagal diukur (LiDAR nggak bisa
    /// baca depth di titik itu — ada sembilan jalur gagal di ARAreaCalculator)
    /// DIAM-DIAM nggak ikut dijumlah. Tanpa penanda, totalnya kelihatan seperti
    /// bukan akumulasi padahal sebenarnya akumulasi dari yang terukur aja.
    var measuredFindingCount: Int {
        inspection.findings.filter { $0.areaCM2 != nil }.count
    }

    var totalFindingCount: Int { inspection.findings.count }

    /// Catatan kecil di bawah Total Mold Area. `nil` kalau semua temuan
    /// kebetulan berhasil diukur — nggak ada yang perlu dijelasin.
    var areaCoverageNote: String? {
        guard totalFindingCount > 0 else { return nil }
        if measuredFindingCount == 0 {
            return "None of the \(totalFindingCount) detections could be measured"
        }
        if measuredFindingCount < totalFindingCount {
            return "Summed from \(measuredFindingCount) of \(totalFindingCount) detections. The rest couldn't be measured by the depth sensor."
        }
        return "Summed from all \(totalFindingCount) detection\(totalFindingCount == 1 ? "" : "s")"
    }

    /// Total luas jamur yang kedeteksi, diformat "0,96 m²" — nil kalau gak ada
    /// satu pun temuan yang berhasil diukur (LiDAR gagal baca depth-nya).
    /// Dalam cm², BUKAN m².
    ///
    /// Luas jamur di ruangan itu kecil — ambang "Light" aja cuma 600 cm². Dalam
    /// m² angkanya jadi "0,06" yang susah dibayangin dan kelihatan sepele;
    /// dalam cm² langsung kebayang seluas apa.
    var totalAreaText: String? {
        guard let cm2 = inspection.totalAreaCM2 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: cm2)) ?? String(format: "%.0f", cm2)
        return "\(formatted) cm²"
    }

    /// Hapus satu FOTO.
    ///
    /// Kalau fotonya punya temuan, yang dihapus SEMUA temuan dari jepretan itu
    /// (`captureID` sama) — bukan satu temuan doang, karena yang dilihat user
    /// itu satu foto. Kalau nggak punya temuan, yang dihapus foto polosnya.
    func deletePhoto(captureID: UUID?, plainPhotoOffset: Int?) {
        if let captureID {
            inspection.findings.removeAll { $0.captureID == captureID }
        } else if let plainPhotoOffset, plainPhotoOffset < inspection.capturedPhotos.count {
            inspection.capturedPhotos.remove(at: plainPhotoOffset)
        } else {
            return
        }
        recomputeSeverity()
        persistPhotoEditIfSaved()
    }

    /// Keparahan turun dari total luas jamur, jadi harus dihitung ulang tiap
    /// kali fotonya berubah — kalau nggak, angkanya bohong.
    private func recomputeSeverity() {
        let totalArea = inspection.findings.compactMap(\.areaCM2).reduce(0, +)
        inspection.moldSeverityLevel = totalArea > 0
            ? MoldSeverity.severity(fromAreaCM2: totalArea).level
            : 0
        // Keparahan itu input model, jadi prediksinya harus dihitung ulang.
        cachedPrediction = nil

        // `riskLevel` yang tersimpan ikut diperbarui — itu yang dibaca pil di
        // kartu ruangan. Kalau nggak diikutin, kartunya nunjukin angka lama
        // sementara report-nya udah beda.
        if let updated = RiskLevel.level(fromClassifier: prediction?.riskClass) {
            inspection.riskLevel = updated
        }
    }

    private func persistPhotoEditIfSaved() {
        guard case .saved(let propertyID) = source else { return }
        store.updateRoomPhotos(
            roomID: inspection.id, ofProperty: propertyID,
            findings: inspection.findings, photos: inspection.capturedPhotos,
            moldSeverityLevel: inspection.moldSeverityLevel, riskLevel: inspection.riskLevel
        )
    }

    func save() {
        guard case .draftExisting(let propertyID, let location) = source else { return }
        store.attachInspection(inspection, toExistingPropertyID: propertyID, location: location)
        store.lastSavedPropertyID = propertyID
    }
}
