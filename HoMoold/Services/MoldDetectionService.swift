//
//  MoldDetectionService.swift
//  HoMoold
//
//  Titik integrasi model AI. Jangan taruh logika deteksi/mock langsung di View —
//  selalu lewat protokol ini supaya implementasi asli tinggal di-drop-in nanti.
//

import CoreGraphics
import Foundation

protocol MoldDetectionService {
    /// Ambil video hasil rekaman, kembalikan hasil deteksi.
    /// Implementasi asli nanti akan: extract frame, jalankan model deteksi
    /// jamur, lalu hitung skor risiko dari kondisi kerusakan yang terdeteksi
    /// + data cuaca.
    func analyze(videoURL: URL, roomType: RoomType) async -> RoomInspection
}

// Model AI asli ada di `RealMoldDetectionService` (pakai MoldDamp.mlpackage,
// di-convert dari .pt lewat ultralytics). Mock ini masih disimpan buat
// #Preview / testing tanpa perlu file video sungguhan.
final class MockMoldDetectionService: MoldDetectionService {

    private let loadingMessages = [
        "Menganalisis video...",
        "Mencari tanda lembap dan retak...",
        "Menghitung skor risiko...",
    ]

    func analyze(videoURL: URL, roomType: RoomType) async -> RoomInspection {
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let findingCount = Int.random(in: 2...7)
        let seed = Int.random(in: 0...9999)
        var findings: [Finding] = []
        let sampleLocations = [
            "sudut plafon dekat jendela", "dinding di atas kusen jendela", "dinding belakang lemari",
            "plafon tengah ruangan", "sudut dinding kanan bawah", "lantai dekat kaki ranjang",
            "dinding samping jendela", "nat keramik lantai", "celah keramik dekat shower",
        ]
        for _ in 0..<findingCount {
            let classType: FindingClass = [.mold, .damp, .crack].randomElement()!
            let center = CGPoint(x: .random(in: 0.15...0.85), y: .random(in: 0.15...0.7))
            let note = sampleLocations.randomElement()!
            let frame = PlaceholderImageFactory.findingFrame(for: roomType, seed: seed, stainAt: center, findingClass: classType)
            let boxSize: CGFloat = 0.16
            let box = CGRect(x: center.x - boxSize / 2, y: center.y - boxSize / 2, width: boxSize, height: boxSize)
            findings.append(Finding(boundingBox: box, frameImage: frame, findingClass: classType, locationNote: note))
        }

        // Makin banyak temuan, makin tinggi skor.
        let baseScore = min(95, findingCount * 12 + Int.random(in: 0...10))
        let riskLevel = RiskLevel.level(forScore: baseScore)

        return RoomInspection(
            roomType: roomType,
            riskLevel: riskLevel,
            riskScore: baseScore,
            findings: findings,
            videoURL: videoURL,
            date: Date()
        )
    }

    var stepMessages: [String] { loadingMessages }
}
