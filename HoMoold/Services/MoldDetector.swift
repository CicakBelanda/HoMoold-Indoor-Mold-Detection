//
//  MoldDetector.swift
//  HoMoold
//
//  Wrapper Vision + CoreML buat MoldDamp (YOLO, di-export dari .pt lewat
//  ultralytics ke .mlpackage, task=detect). Cuma kelas "mold" yang dipakai —
//  lihat catatan di bawah.
//
//  Export ini TIDAK dapet NMS pipeline dari Ultralytics (metadata export-nya
//  nunjukin `nms=False`), jadi Vision gak bisa auto-decode ke
//  VNRecognizedObjectObservation. Box decode + NMS dikerjain manual di sini.
//
//  Output model (dikonfirmasi lewat inspeksi .mlpackage, input 960x960):
//  satu tensor deteksi, shape [1, 6, 18900]: per anchor = 4 box (cx,cy,w,h,
//  piksel 960-space, sudah didecode) + 2 skor kelas — {0: damp, 1: mold},
//  sudah disigmoid. Gak ada koefisien mask (task=detect, bukan segment).
//  Tensor dicari lewat jumlah dimensi (== 3), bukan nama fitur — nama
//  aslinya ("var_1225" dst.) di-generate coremltools dan bisa berubah tiap
//  re-export.
//
//  App-nya cuma mau deteksi jamur, bukan "lembap" — jadi channel kelas
//  "damp" (index 0) di-skip total di decode, model-nya efektif dipakai
//  single-class walau dilatih 2 kelas.
//
//  PENTING kalau model di-ganti/re-export lagi: nama file ("MoldDamp"),
//  ukuran input (960), dan jumlah channel (6 = 4 box + 2 kelas, TANPA mask)
//  semuanya di-hardcode di bawah — kalau modelnya beda arsitektur/ukuran,
//  konstanta ini harus disesuaikan lagi (lihat log `[MoldDetector]` di
//  console buat verifikasi cepat: "channel count mismatch" artinya
//  konstanta di sini udah gak cocok sama model yang di-bundle).
//

import CoreML
import Vision

final class MoldDetector: @unchecked Sendable {
    private let request: VNCoreMLRequest
    private let confidenceThreshold: Float
    private let iouThreshold: Float = 0.45

    private static let trainedClassCount = 2 // {0: damp, 1: mold} — cuma index 1 yang dipakai
    private static let moldClassIndex = 1
    private static let moldLabel = "mold"
    private static let inputSize: CGFloat = 960

    /// Nil kalau model belum ada di bundle — caller harus handle nil dengan
    /// graceful degradation, bukan crash.
    init?(modelName: String, confidenceThreshold: Float = 0.35) {
        // .cpuOnly: model sebelumnya (export coremltools 9.0 dari torch 2.13,
        // "not tested with coremltools" waktu export) bikin runtime CoreML
        // crash SIGABRT ("MPSGraphExecutable ... MLIR pass manager failed")
        // kalau dijalanin lewat compute unit default (.all, coba ANE/GPU
        // dulu). Dipertahankan di sini sebagai default aman — kalau model
        // barunya ternyata gak kena masalah yang sama, ini cuma bikin
        // inference sedikit lebih lambat, bukan salah.
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly

        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("[MoldDetector] \(modelName).mlmodelc not found in bundle — model gak ke-compile/ke-bundle.")
            return nil
        }
        let mlModel: MLModel
        do {
            mlModel = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            print("[MoldDetector] MLModel load failed: \(error)")
            return nil
        }
        guard let visionModel = try? VNCoreMLModel(for: mlModel) else {
            print("[MoldDetector] VNCoreMLModel wrap failed.")
            return nil
        }
        print("[MoldDetector] loaded \(modelName), inputs: \(mlModel.modelDescription.inputDescriptionsByName.keys), "
            + "outputs: \(mlModel.modelDescription.outputDescriptionsByName.keys)")

        let req = VNCoreMLRequest(model: visionModel)
        req.imageCropAndScaleOption = .scaleFill
        self.request = req
        self.confidenceThreshold = confidenceThreshold
    }

    /// Sinkron — panggil dari background queue, bukan main thread.
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return decode(handler)
    }

    func detect(in cgImage: CGImage) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        return decode(handler)
    }

    // MARK: - Decode pipeline

    private struct RawDetection {
        let boxPixels: CGRect // origin kiri-atas, koordinat input model (Self.inputSize x Self.inputSize)
        let confidence: Float
    }

    private func decode(_ handler: VNImageRequestHandler) -> [LiveDetection] {
        do {
            try handler.perform([request])
        } catch {
            print("[MoldDetector] Vision request failed: \(error)")
            return []
        }
        guard let results = request.results else {
            print("[MoldDetector] request.results is nil")
            return []
        }
        guard let observations = results as? [VNCoreMLFeatureValueObservation] else {
            print("[MoldDetector] unexpected result type: \(type(of: results)) — \(results)")
            return []
        }
        let arrays = observations.compactMap(\.featureValue.multiArrayValue)
        guard let detectionArray = arrays.first(where: { $0.shape.count == 3 }) else {
            print("[MoldDetector] no 3D output found. Got shapes: \(arrays.map { $0.shape.map(\.intValue) })")
            return []
        }

        let kept = nonMaxSuppress(decodeDetections(detectionArray))
        return kept.map { detection in
            LiveDetection(
                label: Self.moldLabel,
                confidence: detection.confidence,
                boundingBox: visionBoundingBox(for: detection.boxPixels)
            )
        }
    }

    private func decodeDetections(_ array: MLMultiArray) -> [RawDetection] {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 3 else { return [] }
        let channelCount = shape[1]
        let anchorCount = shape[2]
        let numClasses = channelCount - 4
        guard numClasses == Self.trainedClassCount else {
            print("[MoldDetector] channel count mismatch: got \(channelCount) channels "
                + "(expected 4 + \(Self.trainedClassCount) = \(4 + Self.trainedClassCount), no mask channels) "
                + "— model output shape changed?")
            return []
        }
        guard array.dataType == .float32 else {
            print("[MoldDetector] unexpected dataType: \(array.dataType.rawValue), expected float32")
            return []
        }

        let channelStride = array.strides[1].intValue
        let anchorStride = array.strides[2].intValue
        let ptr = array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)
        func value(_ channel: Int, _ anchor: Int) -> Float {
            ptr[channel * channelStride + anchor * anchorStride]
        }

        var results: [RawDetection] = []
        var maxScoreSeen: Float = -1
        for anchor in 0..<anchorCount {
            let moldScore = value(4 + Self.moldClassIndex, anchor)
            maxScoreSeen = max(maxScoreSeen, moldScore)
            guard moldScore >= confidenceThreshold else { continue }

            let cx = CGFloat(value(0, anchor))
            let cy = CGFloat(value(1, anchor))
            let w = CGFloat(value(2, anchor))
            let h = CGFloat(value(3, anchor))
            let box = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)

            results.append(RawDetection(boxPixels: box, confidence: moldScore))
        }
        // Log walau gak ada yang lolos threshold — biar keliatan model-nya "hampir yakin"
        // (skor deket threshold, tuning issue) vs "gak ngerti sama sekali" (skor deket 0,
        // kemungkinan besar bug preprocessing/orientasi, bukan cuma soal threshold).
        print("[MoldDetector] \(anchorCount) anchors, max mold score = "
            + String(format: "%.3f", maxScoreSeen) + ", threshold = \(confidenceThreshold), "
            + "kept before NMS = \(results.count)")
        return results
    }

    /// NMS standar (greedy) — single-class, jadi gak perlu di-split per kelas lagi.
    private func nonMaxSuppress(_ detections: [RawDetection]) -> [RawDetection] {
        var kept: [RawDetection] = []
        var candidates = detections.sorted { $0.confidence > $1.confidence }
        while let best = candidates.first {
            kept.append(best)
            candidates.removeFirst()
            candidates.removeAll { iou($0.boxPixels, best.boxPixels) > iouThreshold }
        }
        return kept
    }

    private func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return Float(intersectionArea / unionArea)
    }

    /// Box piksel (Self.inputSize-space, origin kiri-atas) -> normalized
    /// koordinat Vision (origin kiri-bawah, y ke atas) — sama seperti yang
    /// dulu dikasih otomatis oleh VNRecognizedObjectObservation, biar
    /// `LiveDetection` konsisten di seluruh app.
    private func visionBoundingBox(for boxPixels: CGRect) -> CGRect {
        let xMinN = boxPixels.minX / Self.inputSize
        let yMinTopN = boxPixels.minY / Self.inputSize
        let widthN = boxPixels.width / Self.inputSize
        let heightN = boxPixels.height / Self.inputSize
        return CGRect(x: xMinN, y: 1 - yMinTopN - heightN, width: widthN, height: heightN)
    }
}
