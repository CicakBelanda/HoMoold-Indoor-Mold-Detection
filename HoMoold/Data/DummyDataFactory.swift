//
//  DummyDataFactory.swift
//  HoMoold
//
//  Seed data supaya app tidak kosong saat pertama dibuka. Semua nilai di sini
//  dummy/mock — lihat MoldDetectionService untuk titik integrasi model AI asli.
//

import UIKit

enum DummyDataFactory {

    static func seedProperties() -> [KosProperty] {
        let calendar = Calendar.current
        let today = Date()
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today) ?? today }

        // MARK: - Kos Nuturale (risiko tinggi, banyak temuan)
        let nuturaleBedroomFindings: [Finding] = [
            makeFinding(room: .bedroom, seed: 1, classType: .mold, center: CGPoint(x: 0.22, y: 0.2), note: "sudut plafon dekat jendela"),
            makeFinding(room: .bedroom, seed: 1, classType: .mold, center: CGPoint(x: 0.7, y: 0.25), note: "dinding di atas kusen jendela"),
            makeFinding(room: .bedroom, seed: 1, classType: .damp, center: CGPoint(x: 0.15, y: 0.62), note: "dinding belakang lemari"),
            makeFinding(room: .bedroom, seed: 1, classType: .crack, center: CGPoint(x: 0.5, y: 0.15), note: "plafon tengah ruangan"),
            makeFinding(room: .bedroom, seed: 1, classType: .mold, center: CGPoint(x: 0.8, y: 0.55), note: "sudut dinding kanan bawah"),
            makeFinding(room: .bedroom, seed: 1, classType: .damp, center: CGPoint(x: 0.35, y: 0.68), note: "lantai dekat kaki ranjang"),
            makeFinding(room: .bedroom, seed: 1, classType: .mold, center: CGPoint(x: 0.6, y: 0.4), note: "dinding samping jendela"),
        ]
        let nuturaleBathroomFindings: [Finding] = [
            makeFinding(room: .bathroom, seed: 2, classType: .mold, center: CGPoint(x: 0.3, y: 0.3), note: "celah keramik dekat shower"),
            makeFinding(room: .bathroom, seed: 2, classType: .damp, center: CGPoint(x: 0.6, y: 0.5), note: "dinding dekat lubang angin"),
        ]
        let nuturale = KosProperty(
            name: "Kos Nuturale",
            location: "Kec. Cisauk",
            thumbnail: PlaceholderImageFactory.roomImage(for: .bedroom, seed: 1),
            rooms: [
                RoomInspection(roomType: .bedroom, riskLevel: .high, riskScore: 82, findings: nuturaleBedroomFindings,
                                ventilationWarning: "Ruangan ini nyaris tidak punya jalan keluar udara. Risiko bisa memburuk lebih cepat dari perkiraan.",
                                hasWindow: true, hasAC: false, videoURL: nil, date: today),
                RoomInspection(roomType: .bathroom, riskLevel: .medium, riskScore: 58, findings: nuturaleBathroomFindings,
                                ventilationWarning: nil, hasWindow: false, hasAC: false, videoURL: nil, date: daysAgo(1)),
            ]
        )

        // MARK: - Kos Studentis (risiko sedang)
        let studentisBedroomFindings: [Finding] = [
            makeFinding(room: .bedroom, seed: 3, classType: .damp, center: CGPoint(x: 0.25, y: 0.22), note: "sudut plafon dekat jendela"),
            makeFinding(room: .bedroom, seed: 3, classType: .crack, center: CGPoint(x: 0.55, y: 0.18), note: "plafon dekat lampu"),
            makeFinding(room: .bedroom, seed: 3, classType: .damp, center: CGPoint(x: 0.7, y: 0.6), note: "dinding belakang meja belajar"),
        ]
        let studentisBathroomFindings: [Finding] = [
            makeFinding(room: .bathroom, seed: 4, classType: .mold, center: CGPoint(x: 0.4, y: 0.35), note: "nat keramik lantai"),
            makeFinding(room: .bathroom, seed: 4, classType: .damp, center: CGPoint(x: 0.65, y: 0.55), note: "dinding dekat bak mandi"),
            makeFinding(room: .bathroom, seed: 4, classType: .mold, center: CGPoint(x: 0.2, y: 0.5), note: "sudut bawah dinding"),
            makeFinding(room: .bathroom, seed: 4, classType: .crack, center: CGPoint(x: 0.5, y: 0.2), note: "plafon dekat exhaust fan"),
        ]
        let studentis = KosProperty(
            name: "Kos Studentis",
            location: "Kec. Cisauk",
            thumbnail: PlaceholderImageFactory.roomImage(for: .bedroom, seed: 3),
            rooms: [
                RoomInspection(roomType: .bedroom, riskLevel: .medium, riskScore: 52, findings: studentisBedroomFindings,
                                ventilationWarning: nil, hasWindow: true, hasAC: true, videoURL: nil, date: daysAgo(32)),
                RoomInspection(roomType: .bathroom, riskLevel: .medium, riskScore: 61, findings: studentisBathroomFindings,
                                ventilationWarning: nil, hasWindow: false, hasAC: false, videoURL: nil, date: daysAgo(32)),
            ]
        )

        // MARK: - Kos Echanto (campuran tinggi & rendah)
        let echantoBedroomFindings: [Finding] = [
            makeFinding(room: .bedroom, seed: 5, classType: .mold, center: CGPoint(x: 0.3, y: 0.25), note: "sudut plafon kiri"),
            makeFinding(room: .bedroom, seed: 5, classType: .mold, center: CGPoint(x: 0.65, y: 0.3), note: "dinding dekat jendela"),
            makeFinding(room: .bedroom, seed: 5, classType: .damp, center: CGPoint(x: 0.5, y: 0.65), note: "lantai dekat pintu"),
            makeFinding(room: .bedroom, seed: 5, classType: .crack, center: CGPoint(x: 0.2, y: 0.5), note: "dinding samping lemari"),
            makeFinding(room: .bedroom, seed: 5, classType: .mold, center: CGPoint(x: 0.75, y: 0.6), note: "sudut dinding kanan"),
        ]
        let echantoBathroomFindings: [Finding] = []
        let echanto = KosProperty(
            name: "Kos Echanto",
            location: "Kec. Padegang",
            thumbnail: PlaceholderImageFactory.roomImage(for: .bedroom, seed: 5),
            rooms: [
                RoomInspection(roomType: .bedroom, riskLevel: .high, riskScore: 76, findings: echantoBedroomFindings,
                                ventilationWarning: "Jendela kamar ini kecil dan jarang dibuka — sirkulasi udaranya minim.",
                                hasWindow: true, hasAC: false, videoURL: nil, date: daysAgo(4)),
                RoomInspection(roomType: .bathroom, riskLevel: .low, riskScore: 18, findings: echantoBathroomFindings,
                                ventilationWarning: nil, hasWindow: true, hasAC: false, videoURL: nil, date: daysAgo(4)),
            ]
        )

        // MARK: - Kos Meilani Residence (risiko rendah, baru 1 ruangan)
        let meilaniFindings: [Finding] = [
            makeFinding(room: .bedroom, seed: 6, classType: .damp, center: CGPoint(x: 0.4, y: 0.3), note: "sudut plafon dekat AC"),
        ]
        let meilani = KosProperty(
            name: "Kos Meilani Residence",
            location: "Kec. Serpong",
            thumbnail: PlaceholderImageFactory.roomImage(for: .bedroom, seed: 6),
            rooms: [
                RoomInspection(roomType: .bedroom, riskLevel: .low, riskScore: 24, findings: meilaniFindings,
                                ventilationWarning: nil, hasWindow: true, hasAC: true, videoURL: nil, date: daysAgo(9)),
            ]
        )

        // MARK: - Kos Bintang Timur (risiko tinggi, kamar mandi parah)
        let bintangBathroomFindings: [Finding] = [
            makeFinding(room: .bathroom, seed: 7, classType: .mold, center: CGPoint(x: 0.25, y: 0.28), note: "dinding dekat shower"),
            makeFinding(room: .bathroom, seed: 7, classType: .mold, center: CGPoint(x: 0.55, y: 0.35), note: "plafon di atas bak mandi"),
            makeFinding(room: .bathroom, seed: 7, classType: .mold, center: CGPoint(x: 0.7, y: 0.6), note: "sudut lantai dekat pintu"),
            makeFinding(room: .bathroom, seed: 7, classType: .damp, center: CGPoint(x: 0.4, y: 0.55), note: "nat keramik dinding"),
            makeFinding(room: .bathroom, seed: 7, classType: .crack, center: CGPoint(x: 0.6, y: 0.2), note: "plafon dekat ventilasi"),
            makeFinding(room: .bathroom, seed: 7, classType: .mold, center: CGPoint(x: 0.3, y: 0.65), note: "lantai dekat saluran air"),
        ]
        let bintang = KosProperty(
            name: "Kos Bintang Timur",
            location: "Kec. Pagedangan",
            thumbnail: PlaceholderImageFactory.roomImage(for: .bathroom, seed: 7),
            rooms: [
                RoomInspection(roomType: .bathroom, riskLevel: .high, riskScore: 88, findings: bintangBathroomFindings,
                                ventilationWarning: "Kamar mandi ini tidak punya ventilasi ke luar sama sekali — udara lembap terjebak di dalam.",
                                hasWindow: false, hasAC: false, videoURL: nil, date: daysAgo(2)),
            ]
        )

        return [nuturale, studentis, echanto, meilani, bintang]
    }

    private static func makeFinding(room: RoomType, seed: Int, classType: FindingClass, center: CGPoint, note: String) -> Finding {
        let frame = PlaceholderImageFactory.findingFrame(for: room, seed: seed, stainAt: center, findingClass: classType)
        let boxSize: CGFloat = 0.16
        let box = CGRect(x: center.x - boxSize / 2, y: center.y - boxSize / 2, width: boxSize, height: boxSize)
        return Finding(boundingBox: box, frameImage: frame, findingClass: classType, locationNote: note)
    }
}
