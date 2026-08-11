//
//  GuidedRecordingController.swift
//  HoMoold
//
//  State machine panduan rekam adaptif: semua dinding -> cari tanda
//  pra-jamur. Sama buat semua tipe ruangan. Maju otomatis berbasis waktu
//  buat step scan dinding, lalu nunjukin hint begitu ada tanda lembap/jamur
//  kedeteksi.
//

import Combine
import Foundation

enum GuideStep: Equatable {
    case scanningWalls
    case lookingForMold
}

@MainActor
final class GuidedRecordingController: ObservableObject {
    let steps: [GuideStep] = [.scanningWalls, .lookingForMold]
    @Published private(set) var stepIndex = 0
    @Published private(set) var lastMoldDetection: LiveDetection?

    private var wallsStartedAt: Date?

    private let wallsScanDuration: TimeInterval = 6.0


    var step: GuideStep { steps[stepIndex] }
    var totalSteps: Int { steps.count }

    var instructionText: String {
        switch step {
        case .scanningWalls:
            return "Geser pelan ke semua dinding & plafon"
        case .lookingForMold:
            if lastMoldDetection != nil {
                return "Kelihatan ada tanda jamur — dekatkan kameranya, lalu tekan rekam buat berhenti"
            }
            return "Perhatikan dinding — kalau ada retak atau jamur, dekatkan kameranya"
        }
    }

    var showDoneHint: Bool {
        step == .lookingForMold && lastMoldDetection != nil
    }

    func processDetections(_ detections: [LiveDetection]) {
        switch step {
        case .scanningWalls:
            break
        case .lookingForMold:
            lastMoldDetection = detections.filter { $0.label == "mold" }.max { $0.confidence < $1.confidence }
        }
    }

    /// Dipanggil tiap ~1 detik dari view buat majuin step berbasis waktu (scanningWalls).
    func tick() {
        guard step == .scanningWalls else { return }
        if wallsStartedAt == nil { wallsStartedAt = Date() }
        if let started = wallsStartedAt, Date().timeIntervalSince(started) >= wallsScanDuration {
            advance()
        }
    }

    private func advance() {
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
        if step == .scanningWalls { wallsStartedAt = nil }
    }
}
