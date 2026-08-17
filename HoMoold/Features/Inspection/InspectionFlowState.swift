//
//  InspectionFlowState.swift
//  HoMoold
//

import Combine
import Foundation
import UIKit

/// Langkah-langkah yang bisa di-push DI ATAS ConditionFormView.
///
/// `condition` sengaja nggak ada di sini: dia layar akarnya (root) NavigationStack,
/// bukan destination yang di-push. Layar pilih tipe ruangan juga udah dihapus —
/// nama & tipe ruangan sekarang diisi langsung di form kondisi.
enum InspectionStep: Hashable {
    /// Cara motret yang bener — muncul pas kamera mau dibuka, 2 halaman.
    case guidance
    case capture
    /// Referensi visual Mold / Mildew / Dampness. Bukan bagian alur maju —
    /// di-push dari guidance atau dari form kondisi, terus di-pop lagi.
    case moldReference
    case loading
    case report
}

@MainActor
final class InspectionFlowState: ObservableObject {
    @Published var path: [InspectionStep] = []

    // Diisi di ConditionFormView — dulu tipe ruangan dipilih di layar terpisah,
    // sekarang nama + tipe dua-duanya di form itu (kartu ruangan di Figma
    // nampilin dua-duanya).
    @Published var roomName = ""
    @Published var roomType: RoomType = .bedroom
    @Published var capturedFindings: [Finding] = []
    /// Foto yang diambil tapi 0 jamur kedeteksi — lihat CaptureViewModel.Outcome.
    @Published var capturedPhotos: [UIImage] = []
    @Published var resultInspection: RoomInspection?

    /// Rumahnya selalu sudah ada duluan — dibuat lewat "Simpan Rumah" dari FAB
    /// Home SEBELUM masuk ke flow ini (lihat alert "Add New House" di HomeListView), jadi Report di
    /// sini selalu langsung "Simpan", gak perlu tanya nama lagi belakangan.
    let existingProperty: KosProperty

    /// Diisi di ConditionFormView (prefill dari `existingProperty.location` —
    /// dengan prefill GPS kalau rumahnya belum punya lokasi sama sekali).
    @Published var location: HomeLocation

    // Diisi di ConditionFormView — kondisi ruangan yang dilaporin manual sama user.
    @Published var hasAC = false
    @Published var hasWindow = false
    @Published var dampness = false
    @Published var wallCrack = false

    /// User bilang ada jamur yang keliatan. Ini yang nentuin tombol bawah di
    /// form kondisi jadi "Next" (buka kamera) atau "Submit" (langsung ke report)
    /// — kalau nggak ada jamur, nggak ada yang perlu difoto.
    @Published var hasVisibleMold = false

    /// Cuaca di tempat user (diambil otomatis lewat WeatherService di
    /// ConditionFormView) — suhu (°C) & kelembapan (%). Disimpan di sini buat
    /// ditampilin + dipakai nanti kalau mau masukin ke RiskClassifier.
    @Published var temperature: Float?
    @Published var humidity: Float?

    init(existingProperty: KosProperty) {
        self.existingProperty = existingProperty
        self.location = existingProperty.location
    }

    /// Rakit hasil inspeksi dari semua yang udah dikumpulin sepanjang flow.
    ///
    /// Dipanggil di `AnalyzingLoadingView` — BUKAN di `ConditionFormView` kayak
    /// dulu. Sejak form kondisi pindah ke sebelum kamera, `capturedFindings`
    /// belum ada isinya waktu form itu selesai, jadi perakitannya harus nunggu
    /// sampai kamera kelar.
    func buildResultInspection() {
        let score = min(95, capturedFindings.count * 12)
        // Level keparahan (0–3) dari total luas jamur — input `Mold` model.
        let totalArea = capturedFindings.compactMap(\.areaCM2).reduce(0, +)
        let moldLevel = totalArea > 0 ? MoldSeverity.severity(fromAreaCM2: totalArea).level : 0

        // Risiko yang DISIMPAN diambil dari RiskClassifier — sumber yang sama
        // dengan yang dipakai halaman Report. Kalau modelnya gagal jalan (mis.
        // cuaca nggak keambil), baru jatuh ke skor jumlah-foto sebagai cadangan.
        let predicted = RiskLevel.level(fromClassifier: predictedRiskClass())
        let riskLevel = predicted ?? RiskLevel.level(forScore: score)

        resultInspection = RoomInspection(
            name: roomName,
            roomType: roomType,
            riskLevel: riskLevel,
            riskScore: score,
            findings: capturedFindings,
            capturedPhotos: capturedPhotos,
            hasAC: hasAC,
            hasWindow: hasWindow,
            dampness: dampness,
            wallCrack: wallCrack,
            date: Date(),
            temperature: temperature,
            humidity: humidity,
            moldSeverityLevel: moldLevel
        )
    }

    /// Jalanin RiskClassifier dengan input yang udah dikumpulin. `nil` kalau
    /// cuaca nggak keambil atau modelnya gagal dimuat.
    private func predictedRiskClass() -> String? {
        guard let t = temperature, let h = humidity else { return nil }
        let totalArea = capturedFindings.compactMap(\.areaCM2).reduce(0, +)
        let moldLevel = totalArea > 0 ? MoldSeverity.severity(fromAreaCM2: totalArea).level : 0
        return (try? RiskClassifierService())?.predict(
            temperature: t, humidity: h,
            hasAC: hasAC, hasWindow: hasWindow,
            dampness: dampness, wallCrack: wallCrack,
            moldLevel: moldLevel
        )
    }
}
