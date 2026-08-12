//
//  MoldDetector.swift
//  HoMoold
//
//  Wrapper Vision + CoreML buat model deteksi jamur (di-export dari .pt lewat
//  ultralytics ke .mlpackage). Adaptif ke DUA bentuk export yang udah pernah
//  dipakai di project ini — task=detect (mis. MoldDamp, 960x960, tensor
//  [1,6,N] — 4 box + 2 kelas, TANPA mask) dan task=segment (mis. MoldDampSeg,
//  640x640, tensor [1,38,N] — 4 box + 2 kelas + 32 koefisien mask, plus
//  tensor proto mask [1,32,H,W] terpisah). Bedanya cuma dari BENTUK output
//  yang dibaca run-time (lihat `decode`), bukan hardcode nama/ukuran model —
//  jadi kalau modelnya di-swap lagi antara dua bentuk ini, gak perlu ubah
//  kode lagi.
//
//  Kedua bentuk export TIDAK dapet NMS pipeline dari Ultralytics kalau
//  di-export dengan `nms=False` (dikonfirmasi lewat metadata `.mlpackage`,
//  key `args`) — jadi Vision gak bisa auto-decode ke
//  VNRecognizedObjectObservation. Box decode + NMS dikerjain manual di sini,
//  buat kedua bentuk.
//
//  App-nya cuma mau deteksi jamur, bukan "lembap" — jadi channel kelas
//  "damp" (index 0) di-skip total di decode, model-nya efektif dipakai
//  single-class walau dilatih 2 kelas.
//
//  Request-nya pakai `.scaleFill` (stretch langsung ke kotak inputSize,
//  bukan letterbox) — sempat dicoba ganti ke `.scaleFit` + unletterbox
//  koordinatnya buat coba benerin akurasi deteksi yang jelek, tapi ternyata
//  bikin deteksi yang tadinya jalan jadi berhenti sama sekali. Dibalikin ke
//  `.scaleFill` + mapping langsung (`box / inputSize`, tanpa letterbox).
//

import CoreML
import Vision

final class MoldDetector: @unchecked Sendable {
    private let request: VNCoreMLRequest
    private let confidenceThreshold: Float
    private let iouThreshold: Float = 0.45
    /// Ukuran input model (persegi — 640 buat MoldDampSeg, 960 buat MoldDamp,
    /// dst.), dibaca dari model description pas load, bukan di-hardcode.
    private let inputSize: CGFloat

    /// Ringkasan tick terakhir buat ditampilin di layar (bukan cuma console) —
    /// biar bisa didiagnosa dari HP langsung tanpa perlu buka Xcode. Ditulis di
    /// background queue lewat `decode`, dibaca setelahnya di call site yang sama
    /// (bukan concurrent read/write), jadi aman walau bukan actor-isolated.
    private(set) var lastDiagnostics = "belum ada frame diproses"

    private static let trainedClassCount = 2 // {0: damp, 1: mold} — cuma index 1 yang dipakai
    private static let moldClassIndex = 1
    private static let moldLabel = "mold"
    /// Jumlah prototype mask standar YOLO-seg (Ultralytics) — dipakai buat
    /// nebak apakah tensor deteksi-nya bentuk "segment" (ada koefisien mask)
    /// atau "detect" biasa (gak ada), lihat `decode`.
    private static let standardMaskCoefficientCount = 32

    /// Nil kalau model belum ada di bundle — caller harus handle nil dengan
    /// graceful degradation, bukan crash.
    init?(modelName: String, confidenceThreshold: Float = 0.35) {
        // .cpuOnly: model-model yang udah dicoba di project ini (export
        // coremltools 9.0 dari torch 2.13, "not tested with coremltools"
        // waktu export) bikin runtime CoreML crash SIGABRT
        // ("MPSGraphExecutable ... MLIR pass manager failed") kalau
        // dijalanin lewat compute unit default (.all, coba ANE/GPU dulu).
        // Dipertahankan sebagai default aman — kalau model barunya ternyata
        // gak kena masalah yang sama, ini cuma bikin inference sedikit lebih
        // lambat, bukan salah.
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
        guard let inputDescription = mlModel.modelDescription.inputDescriptionsByName.values.first,
              inputDescription.type == .image,
              let imageConstraint = inputDescription.imageConstraint else {
            print("[MoldDetector] model input bukan image type, gak bisa baca ukurannya.")
            return nil
        }
        self.inputSize = CGFloat(imageConstraint.pixelsWide)
        print("[MoldDetector] loaded \(modelName), input size \(imageConstraint.pixelsWide)x\(imageConstraint.pixelsHigh), "
            + "outputs: \(mlModel.modelDescription.outputDescriptionsByName.keys)")

        let req = VNCoreMLRequest(model: visionModel)
        req.imageCropAndScaleOption = .scaleFill
        self.request = req
        self.confidenceThreshold = confidenceThreshold
    }

    /// Sinkron — panggil dari background queue, bukan main thread. Box aja,
    /// mask (kalau ada) diabaikan — lebih ringan buat live guidance.
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return decode(handler, wantMasks: false).map(\.asLiveDetection)
    }

    /// Versi CGImage — dipakai dari frame yang UDAH di-render tegak (lihat
    /// FrameImageRenderer di CaptureViewModel), `orientation: .up` karena
    /// gambarnya udah pasti bener orientasinya, gak perlu dirotate lagi. Ini
    /// jalur yang sama kayak alur video lama (RealMoldDetectionService) yang
    /// kebukti akurat — dipakai lagi di sini karena jalur pixelBuffer mentah
    /// + rotasi manual di atas ternyata kurang bisa diandalkan buat model ini.
    func detect(in cgImage: CGImage) -> [LiveDetection] {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        return decode(handler, wantMasks: false).map(\.asLiveDetection)
    }

    /// Versi lengkap dengan mask piksel — dipakai buat overlay + kalkulasi
    /// luas LiDAR (lihat ARAreaCalculator). Kalau model yang di-bundle gak
    /// punya output proto mask (task=detect biasa), mask-nya bakal kosong
    /// (maskWidth/maskHeight 0) — caller harus fallback ke box aja.
    func detectWithMasks(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [SegmentationInstance] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return decode(handler, wantMasks: true).map(\.asSegmentationInstance)
    }

    /// Versi CGImage dari `detectWithMasks` — lihat catatan di `detect(in cgImage:)`.
    func detectWithMasks(in cgImage: CGImage) -> [SegmentationInstance] {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        return decode(handler, wantMasks: true).map(\.asSegmentationInstance)
    }

    // MARK: - Decode pipeline

    private struct Decoded {
        let label: String
        let confidence: Float
        let visionBoundingBox: CGRect
        let mask: (values: [Bool], width: Int, height: Int)?

        var asLiveDetection: LiveDetection {
            LiveDetection(label: label, confidence: confidence, boundingBox: visionBoundingBox)
        }

        var asSegmentationInstance: SegmentationInstance {
            SegmentationInstance(
                label: label,
                confidence: confidence,
                boundingBox: visionBoundingBox,
                mask: mask?.values ?? [],
                maskWidth: mask?.width ?? 0,
                maskHeight: mask?.height ?? 0
            )
        }
    }

    private struct RawDetection {
        let boxPixels: CGRect // origin kiri-atas, koordinat input model (inputSize x inputSize)
        let confidence: Float
        let maskCoefficients: [Float] // kosong kalau model-nya gak punya proto mask
    }

    private func decode(_ handler: VNImageRequestHandler, wantMasks: Bool) -> [Decoded] {
        do {
            try handler.perform([request])
        } catch {
            lastDiagnostics = "Vision request GAGAL: \(error.localizedDescription)"
            print("[MoldDetector] \(lastDiagnostics)")
            return []
        }
        guard let results = request.results else {
            lastDiagnostics = "request.results nil — Vision gak balikin apa-apa"
            print("[MoldDetector] \(lastDiagnostics)")
            return []
        }
        guard let observations = results as? [VNCoreMLFeatureValueObservation] else {
            lastDiagnostics = "hasil Vision tipe gak terduga: \(type(of: results))"
            print("[MoldDetector] \(lastDiagnostics) — \(results)")
            return []
        }
        let arrays = observations.compactMap(\.featureValue.multiArrayValue)
        guard let detectionArray = arrays.first(where: { $0.shape.count == 3 }) else {
            lastDiagnostics = "gak ketemu output 3D. Shape yang ada: \(arrays.map { $0.shape.map(\.intValue) })"
            print("[MoldDetector] \(lastDiagnostics)")
            return []
        }
        // Proto mask tensor (task=segment) selalu 4D [1, 32, H, W]; model
        // task=detect biasa gak punya tensor ini sama sekali.
        let protoArray = arrays.first(where: { $0.shape.count == 4 })
        let maskCoefficientCount = protoArray != nil ? Self.standardMaskCoefficientCount : 0

        let kept = nonMaxSuppress(decodeDetections(detectionArray, maskCoefficientCount: maskCoefficientCount))
        return kept.map { detection in
            Decoded(
                label: Self.moldLabel,
                confidence: detection.confidence,
                visionBoundingBox: visionBoundingBox(for: detection.boxPixels),
                mask: (wantMasks && !detection.maskCoefficients.isEmpty)
                    ? protoArray.map { decodeMask(coefficients: detection.maskCoefficients, proto: $0, box: detection.boxPixels) }
                    : nil
            )
        }
    }

    private func decodeDetections(_ array: MLMultiArray, maskCoefficientCount: Int) -> [RawDetection] {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 3 else { return [] }
        let channelCount = shape[1]
        let anchorCount = shape[2]
        let numClasses = channelCount - 4 - maskCoefficientCount
        guard numClasses == Self.trainedClassCount else {
            lastDiagnostics = "channel count mismatch: \(channelCount) channels, asumsi \(maskCoefficientCount) "
                + "mask coeffs -> \(numClasses) kelas (harusnya \(Self.trainedClassCount)) — shape model berubah?"
            print("[MoldDetector] \(lastDiagnostics)")
            return []
        }
        guard array.dataType == .float32 else {
            lastDiagnostics = "dataType gak terduga: \(array.dataType.rawValue), harusnya float32"
            print("[MoldDetector] \(lastDiagnostics)")
            return []
        }

        let channelStride = array.strides[1].intValue
        let anchorStride = array.strides[2].intValue
        let ptr = array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)
        func value(_ channel: Int, _ anchor: Int) -> Float {
            ptr[channel * channelStride + anchor * anchorStride]
        }

        var results: [RawDetection] = []
        var maxScoreSeen: Float = -.infinity
        var minScoreSeen: Float = .infinity
        var maxDampSeen: Float = -.infinity
        var bestAnchor: Int?
        for anchor in 0..<anchorCount {
            let moldScore = value(4 + Self.moldClassIndex, anchor)
            let dampScore = value(4, anchor) // index 0 = damp, dipakai cuma buat diagnostik di sini
            if moldScore > maxScoreSeen { maxScoreSeen = moldScore; bestAnchor = anchor }
            minScoreSeen = min(minScoreSeen, moldScore)
            maxDampSeen = max(maxDampSeen, dampScore)
            guard moldScore >= confidenceThreshold else { continue }

            let cx = CGFloat(value(0, anchor))
            let cy = CGFloat(value(1, anchor))
            let w = CGFloat(value(2, anchor))
            let h = CGFloat(value(3, anchor))
            let box = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)

            var coefficients: [Float] = []
            if maskCoefficientCount > 0 {
                coefficients = (0..<maskCoefficientCount).map { value(4 + numClasses + $0, anchor) }
            }

            results.append(RawDetection(boxPixels: box, confidence: moldScore, maskCoefficients: coefficients))
        }
        // Log walau gak ada yang lolos threshold — biar keliatan model-nya "hampir yakin"
        // (skor deket threshold, tuning issue) vs "gak ngerti sama sekali" (skor deket 0,
        // kemungkinan besar bug preprocessing/orientasi, bukan cuma soal threshold).
        //
        // min/max mold score dicetak buat cek satu hal spesifik: kalau ADA nilai NEGATIF
        // atau di luar rentang 0...1, berarti output model ini masih LOGIT MENTAH (belum
        // lewat sigmoid) dan kode ini salah nganggepnya udah jadi probabilitas — beda bug
        // sama sekali dari threshold/orientasi/preprocessing yang udah dicoba.
        var boxDump = ""
        if let bestAnchor {
            let cx = value(0, bestAnchor), cy = value(1, bestAnchor)
            let w = value(2, bestAnchor), h = value(3, bestAnchor)
            boxDump = String(format: ", box anchor terbaik: cx=%.3f cy=%.3f w=%.3f h=%.3f", cx, cy, w, h)
        }
        let summary = "\(anchorCount) anchors, mask coeffs = \(maskCoefficientCount), mold score min="
            + String(format: "%.4f", minScoreSeen) + " max=" + String(format: "%.4f", maxScoreSeen)
            + ", max damp score=" + String(format: "%.4f", maxDampSeen)
            + ", threshold = \(confidenceThreshold), kept before NMS = \(results.count)" + boxDump
        print("[MoldDetector] \(summary)")
        lastDiagnostics = summary
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

    /// Box piksel (inputSize-space, origin kiri-atas) -> normalized koordinat
    /// Vision (origin kiri-bawah, y ke atas) — sama seperti yang dulu dikasih
    /// otomatis oleh VNRecognizedObjectObservation, biar `LiveDetection`
    /// konsisten di seluruh app.
    private func visionBoundingBox(for boxPixels: CGRect) -> CGRect {
        let xMinN = boxPixels.minX / inputSize
        let yMinTopN = boxPixels.minY / inputSize
        let widthN = boxPixels.width / inputSize
        let heightN = boxPixels.height / inputSize
        return CGRect(x: xMinN, y: 1 - yMinTopN - heightN, width: widthN, height: heightN)
    }

    /// mask = sigmoid(coeff . proto), di-crop ke box-nya sendiri (di luar box
    /// dianggap false biar gak nge-leak ke instance lain yang overlap).
    private func decodeMask(coefficients: [Float], proto: MLMultiArray, box: CGRect) -> (values: [Bool], width: Int, height: Int) {
        let shape = proto.shape.map(\.intValue)
        guard shape.count == 4, proto.dataType == .float32 else { return ([], 0, 0) }
        let channelCount = shape[1]
        let height = shape[2]
        let width = shape[3]
        guard channelCount == coefficients.count else { return ([], 0, 0) }

        let channelStride = proto.strides[1].intValue
        let rowStride = proto.strides[2].intValue
        let colStride = proto.strides[3].intValue
        let ptr = proto.dataPointer.bindMemory(to: Float32.self, capacity: proto.count)

        let scale = CGFloat(width) / inputSize // proto biasanya 1/4 resolusi input model
        let boxInProto = CGRect(
            x: box.minX * scale, y: box.minY * scale,
            width: box.width * scale, height: box.height * scale
        )

        var values = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            guard CGFloat(y) >= boxInProto.minY, CGFloat(y) < boxInProto.maxY else { continue }
            for x in 0..<width {
                guard CGFloat(x) >= boxInProto.minX, CGFloat(x) < boxInProto.maxX else { continue }
                var sum: Float = 0
                for c in 0..<channelCount {
                    sum += coefficients[c] * ptr[c * channelStride + y * rowStride + x * colStride]
                }
                values[y * width + x] = (1 / (1 + exp(-sum))) > 0.5
            }
        }
        return (values, width, height)
    }
}
