//
//  RealMoldDetectionService.swift
//  HoMoold
//
//  Implementasi asli MoldDetectionService — pakai model YOLO yang sudah
//  dilatih (MoldDamp.mlpackage, tapi cuma kelas "mold" yang dipakai — lihat
//  MoldDetector), di-convert dari .pt lewat ultralytics export ke CoreML.
//  Video hasil rekaman di-sample tiap setengah detik, tiap frame dijalankan
//  lewat model, hasilnya digabung jadi Finding + skor risiko.
//

import AVFoundation
import CoreGraphics
import UIKit
import Vision

final class RealMoldDetectionService: MoldDetectionService {
    private let moldDetector = MoldDetector(modelName: "MoldDamp", confidenceThreshold: 0.35)

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

        let sampleCount = max(1, Int(durationSeconds / sampleInterval))
        for index in 0..<sampleCount {
            let time = CMTime(seconds: Double(index) * sampleInterval, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }

            guard let moldDetector, findings.count < maxFindings else { continue }
            let uiImage = UIImage(cgImage: cgImage)
            for detection in moldDetector.detect(in: cgImage) {
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

        let baseScore = min(95, findings.count * 12)
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
