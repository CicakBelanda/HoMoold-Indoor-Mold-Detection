//
//  RealMoldDetectionService.swift
//  HoMoold
//
//  Implementasi asli MoldDetectionService — pakai dua model YOLO yang sudah
//  dilatih (MoldDamp.mlpackage: damp/mold, WindowAC.mlpackage: AC/Window,
//  di-convert dari MoldDamp.pt & WindowAC.pt lewat ultralytics export ke
//  CoreML). Video hasil rekaman di-sample tiap setengah detik, tiap frame
//  dijalankan lewat kedua model, hasilnya digabung jadi Finding + status
//  ventilasi + skor risiko.
//

import AVFoundation
import CoreGraphics
import UIKit
import Vision

final class RealMoldDetectionService: MoldDetectionService {
    private let windowACDetector = LiveObjectDetector(modelName: "WindowAC", confidenceThreshold: 0.4)
    private let moldDampDetector = LiveObjectDetector(modelName: "MoldDamp", confidenceThreshold: 0.35)

    private let sampleInterval: Double = 0.5
    private let maxFindings = 8
    private let dedupeDistance: CGFloat = 0.12

    func analyze(videoURL: URL, roomType: RoomType) async -> RoomInspection {
        let asset = AVURLAsset(url: videoURL)
        let durationSeconds = (try? await asset.load(.duration).seconds) ?? 0

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var findings: [Finding] = []
        var hasWindow = false
        var hasAC = false

        let sampleCount = max(1, Int(durationSeconds / sampleInterval))
        for index in 0..<sampleCount {
            let time = CMTime(seconds: Double(index) * sampleInterval, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }

            if let windowACDetector {
                let detections = windowACDetector.detect(in: cgImage)
                if detections.contains(where: { $0.label == "AC" }) { hasAC = true }
                if detections.contains(where: { $0.label == "Window" }) { hasWindow = true }
            }

            guard let moldDampDetector, findings.count < maxFindings else { continue }
            let uiImage = UIImage(cgImage: cgImage)
            for detection in moldDampDetector.detect(in: cgImage) {
                guard let findingClass = FindingClass(rawValue: detection.label.uppercased()) else { continue }
                let box = detection.uiKitBoundingBox
                let isDuplicate = findings.contains { existing in
                    existing.findingClass == findingClass && distance(existing.boundingBox, box) < dedupeDistance
                }
                guard !isDuplicate, findings.count < maxFindings else { continue }
                findings.append(Finding(
                    boundingBox: box,
                    frameImage: uiImage,
                    findingClass: findingClass,
                    locationNote: locationNote(for: box)
                ))
            }
        }

        let ventilationPenalty = (hasWindow ? 0 : 10) + (hasAC ? 0 : 5)
        let baseScore = min(95, findings.count * 12 + ventilationPenalty)
        let riskLevel = RiskLevel.level(forScore: baseScore)
        let ventilationWarning = (!hasWindow && !hasAC)
            ? "Ruangan ini nyaris tidak punya jalan keluar udara. Risiko bisa memburuk lebih cepat dari perkiraan."
            : nil

        return RoomInspection(
            roomType: roomType,
            riskLevel: riskLevel,
            riskScore: baseScore,
            findings: findings,
            ventilationWarning: ventilationWarning,
            hasWindow: hasWindow,
            hasAC: hasAC,
            videoURL: videoURL,
            date: Date()
        )
    }

    private func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return (dx * dx + dy * dy).squareRoot()
    }

    private func locationNote(for box: CGRect) -> String {
        let vertical: String
        if box.midY < 0.33 {
            vertical = "dekat plafon"
        } else if box.midY > 0.66 {
            vertical = "dekat lantai"
        } else {
            vertical = "di tengah dinding"
        }
        if box.midX < 0.33 {
            return "\(vertical), sisi kiri"
        } else if box.midX > 0.66 {
            return "\(vertical), sisi kanan"
        }
        return vertical
    }
}
