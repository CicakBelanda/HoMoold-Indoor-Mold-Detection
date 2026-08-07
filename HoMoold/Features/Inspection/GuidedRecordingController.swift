//
//  GuidedRecordingController.swift
//  HoMoold
//
//  State machine panduan rekam adaptif. Urutan step-nya beda per tipe ruangan
//  (kamar mandi/dapur skip step AC — jarang ada AC di situ), lalu jendela ->
//  semua dinding -> cari tanda pra-jamur. Maju otomatis kalau targetnya
//  kedeteksi stabil (bukan sekali kedip), tapi user bisa skip manual atau
//  nunggu waktunya lewat buat step yang time-based.
//

import Combine
import Foundation

enum GuideStep: Equatable {
    case lookingForAC
    case lookingForWindow
    case scanningWalls
    case lookingForMold
}

private extension RoomType {
    /// Step mana yang relevan buat tipe ruangan ini — jangan minta cari AC di
    /// kamar mandi/dapur yang hampir pasti gak punya.
    var guideSteps: [GuideStep] {
        switch self {
        case .bedroom, .livingRoom:
            return [.lookingForAC, .lookingForWindow, .scanningWalls, .lookingForMold]
        case .bathroom, .kitchen:
            return [.lookingForWindow, .scanningWalls, .lookingForMold]
        }
    }
}

@MainActor
final class GuidedRecordingController: ObservableObject {
    let steps: [GuideStep]
    @Published private(set) var stepIndex = 0
    @Published private(set) var lastMoldDetection: LiveDetection?

    private var acSustainedSince: Date?
    private var windowSustainedSince: Date?
    private var wallsStartedAt: Date?

    private let sustainDuration: TimeInterval = 1.0
    private let wallsScanDuration: TimeInterval = 6.0

    init(roomType: RoomType?) {
        self.steps = (roomType ?? .bedroom).guideSteps
    }

    var step: GuideStep { steps[stepIndex] }
    var totalSteps: Int { steps.count }

    var instructionText: String {
        switch step {
        case .lookingForAC:
            return "Arahkan kamera ke AC dulu, kalau kamar ini ada AC-nya"
        case .lookingForWindow:
            return "Sekarang arahkan ke jendela atau ventilasi"
        case .scanningWalls:
            return "Geser pelan ke semua dinding & plafon"
        case .lookingForMold:
            if lastMoldDetection != nil {
                return "Kelihatan ada tanda lembap/jamur — dekatkan kameranya, lalu tekan rekam buat berhenti"
            }
            return "Perhatikan dinding — kalau ada retak, noda lembap, atau jamur, dekatkan kameranya"
        }
    }

    var canSkip: Bool {
        step == .lookingForAC || step == .lookingForWindow
    }

    var showDoneHint: Bool {
        step == .lookingForMold && lastMoldDetection != nil
    }

    func skip() {
        advance()
    }

    func processDetections(_ detections: [LiveDetection]) {
        switch step {
        case .lookingForAC:
            let found = detections.contains { $0.label == "AC" }
            handleSustained(detected: found, since: &acSustainedSince, onSustained: advance)
        case .lookingForWindow:
            let found = detections.contains { $0.label == "Window" }
            handleSustained(detected: found, since: &windowSustainedSince, onSustained: advance)
        case .scanningWalls:
            break
        case .lookingForMold:
            let moldFindings = detections.filter { $0.label == "mold" || $0.label == "damp" }
            lastMoldDetection = moldFindings.max { $0.confidence < $1.confidence }
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

    private func handleSustained(detected: Bool, since: inout Date?, onSustained: () -> Void) {
        if detected {
            if since == nil { since = Date() }
            if let start = since, Date().timeIntervalSince(start) >= sustainDuration {
                onSustained()
            }
        } else {
            since = nil
        }
    }

    private func advance() {
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
        if step == .scanningWalls { wallsStartedAt = nil }
    }
}
