//
//  LiveObjectDetector.swift
//  HoMoold
//
//  Wrapper Vision + CoreML buat satu model YOLO (di-export dari .pt lewat
//  ultralytics ke .mlpackage, dengan nms=True supaya Vision otomatis kasih
//  balik VNRecognizedObjectObservation). Dipakai buat live guidance pas
//  rekam — bukan buat hasil final Report (lihat RealMoldDetectionService).
//

import CoreML
import Vision

final class LiveObjectDetector: @unchecked Sendable {
    private let request: VNCoreMLRequest
    private let confidenceThreshold: Float

    /// Nil kalau model belum ada di bundle (misal build tanpa .mlpackage) — caller
    /// harus handle nil dengan graceful degradation, bukan crash.
    init?(modelName: String, confidenceThreshold: Float = 0.45) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: modelURL),
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            return nil
        }
        let req = VNCoreMLRequest(model: visionModel)
        req.imageCropAndScaleOption = .scaleFill
        self.request = req
        self.confidenceThreshold = confidenceThreshold
    }

    /// Sinkron — panggil dari background queue, bukan main thread. Dipakai buat live
    /// guidance dari frame kamera (CVPixelBuffer, belum ada rotasi bawaan).
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return runRequest(handler)
    }

    /// Dipakai buat analisis pasca-rekam dari frame video yang sudah diekstrak
    /// (CGImage sudah tegak lewat `appliesPreferredTrackTransform`).
    func detect(in cgImage: CGImage) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        return runRequest(handler)
    }

    private func runRequest(_ handler: VNImageRequestHandler) -> [LiveDetection] {
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return [] }
        return results.compactMap { observation in
            guard let top = observation.labels.first, top.confidence >= confidenceThreshold else { return nil }
            return LiveDetection(label: top.identifier, confidence: top.confidence, boundingBox: observation.boundingBox)
        }
    }
}
