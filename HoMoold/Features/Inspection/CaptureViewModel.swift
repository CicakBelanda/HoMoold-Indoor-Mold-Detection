//
//  CaptureViewModel.swift
//  HoMoold
//
//  Alur layar ambil foto jamur pas inspeksi (LiDAR):
//  1. SCANNING — kamera live, TANPA overlay apa-apa. Cuma indikator merah/hijau
//     + teks panduan ("deketin", "kejauhan", dst). Deteksi jalan di background
//     tiap ~0.4 detik, tapi hasilnya gak digambar — cuma dipakai buat nentuin
//     warna indikator + panduan.
//  2. STABILIZING — begitu jamur kedeteksi DAN jaraknya masuk jangkauan LiDAR,
//     mulai hitung mundur (`requiredStableTicks`) biar user sempat nahan
//     kamera dulu. Kalau deteksinya ilang/goyang, hitungannya reset.
//  3. READY — indikator hijau, user tinggal pencet tombol ambil gambar.
//  4. PREVIEW — frame-nya dibekukan jadi UIImage, dijalanin deteksi lengkap
//     (pakai mask) + hitung luas, terus ditampilin bounding box + angka
//     luasnya di atas foto itu. User bisa Ulangi (buang, scan ulang titik yang
//     sama), Jamur Lain (terima + scan titik lain), atau Selesai (terima +
//     tutup layar, findings-nya dibalikin ke flow inspeksi).
//
//  Kenapa deteksi pas scanning cuma pakai `detect` (box aja) dan baru pakai
//  `detectWithMasks` pas capture: decode mask itu berat (dot product 32
//  koefisien x seluruh proto mask per instance), gak perlu dijalanin 2-3 kali
//  per detik kalau hasilnya toh gak digambar.
//
//  Deteksi dijalanin di atas CGImage yang UDAH di-render tegak (bukan
//  langsung di CVPixelBuffer mentah ARKit + orientasi manual) — jalur
//  pixelBuffer-langsung ternyata gak akurat (skor model selalu deket 0 walau
//  jamurnya jelas kelihatan), sementara jalur CGImage ini persis yang dulu
//  dipakai pas alur rekam video (RealMoldDetectionService) dan kebukti jalan.
//

import ARKit
import AVFoundation // AVCaptureDevice — buat kontrol torch (lihat setTorch)
import Combine
import CoreImage
import UIKit

/// Bukan bagian dari class @MainActor di bawah, biar bisa dipanggil dari
/// background task. `sharedContext` di-reuse (bukan bikin CIContext baru tiap
/// panggilan) karena sekarang dipanggil tiap tick scanning (~2-3x/detik), bukan
/// cuma sekali pas capture — CIContext mahal buat diinisialisasi berkali-kali.
private enum FrameImageRenderer {
    private static let sharedContext = CIContext()

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// `capturedImage` itu buffer sensor mentah (landscape). `.oriented(.right)`
    /// muterin ke tegak/portrait, sama kayak yang dulu dipakai buat extract
    /// frame dari video — hasilnya CGImage yang orientasinya udah pasti bener,
    /// jadi deteksi di atasnya tinggal pakai `orientation: .up` (lihat MoldDetector).
    ///
    /// `colorSpace: sRGB` dipaksa eksplisit — tanpa ini, CIContext bisa nge-render
    /// ke working color space bawaannya sendiri (bisa extended-range/linear),
    /// yang keliatan normal pas ditampilin ke layar (system color-manage otomatis)
    /// tapi nilai piksel mentahnya bisa kebaca beda banget sama yang CoreML
    /// harapkan — diduga ini penyebab skor model selalu deket 0 di semua anchor.
    nonisolated static func uprightCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        return sharedContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: sRGB)
    }
}

/// Mode layar kamera: deteksi ML otomatis vs tandai manual.
enum CaptureMode: String, CaseIterable, Identifiable {
    case auto
    case manual

    var id: String { rawValue }

    /// Label buat segmented control.
    var label: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        }
    }
}

@MainActor
final class CaptureViewModel: ObservableObject {

    enum ScanPhase {
        case scanning     // belum ada jamur kedeteksi / jarak belum pas
        case stabilizing  // udah kedeteksi, lagi nunggu user nahan kamera
        case ready        // stabil, siap dijepret
    }

    struct CapturedDetection: Identifiable {
        let id = UUID()
        let box: CGRect // UIKit-normalized (origin kiri-atas), ruang "upright"
        let mask: SegmentationInstance?
        let confidence: Float
        let areaCM2: Double?
        let areaText: String?
        let note: String?
    }

    struct CapturedResult {
        let image: UIImage
        let detections: [CapturedDetection]
    }

    @Published private(set) var phase: ScanPhase = .scanning
    @Published private(set) var stabilizeProgress: Double = 0
    @Published private(set) var guidanceText = "Find mold-like objects on surface"

    /// Lampu kamera. ARKit nggak ngasih kontrol torch lewat konfigurasinya, jadi
    /// diatur langsung ke AVCaptureDevice-nya — lihat `toggleTorch`.
    @Published private(set) var isTorchOn = false
    @Published private(set) var isCapturing = false
    @Published private(set) var captured: CapturedResult?
    @Published private(set) var captureError: String?
    @Published private(set) var isWaitingForDepth = false
    @Published private(set) var modelUnavailable = false
    @Published private(set) var debugText = ""
    /// Cahaya lagi kurang — dipakai CaptureView buat nampilin peringatan
    /// "pindah ke tempat lebih terang / nyalain flash". Diperbarui tiap tick
    /// dari estimasi luminansinya frame kamera.
    @Published private(set) var isLightTooDim = false
    /// Jumlah foto yang udah diterima (Jamur Lain / Selesai) — ditampilin di
    /// UI biar user tahu progres di ruangan ini.
    @Published private(set) var acceptedFindings: [Finding] = []
    /// Foto yang diterima tapi 0 jamur kedeteksi di dalamnya — tetap disimpan
    /// (bukan dibuang gitu aja) biar Report tetep nunjukin foto aslinya,
    /// bukan ilustrasi placeholder generik.
    @Published private(set) var acceptedPhotos: [UIImage] = []

    let arSession = ARDepthCaptureSession()

    /// Mode penanda: `.auto` pakai deteksi ML, `.manual` user yang tandain
    /// polygongnya sendiri lewat raycast LiDAR (lihat ARPassthroughView).
    /// `didSet` jalanin ulang sesi AR dengan konfigurasi yang sesuai.
    @Published var captureMode: CaptureMode = .auto {
        didSet { applyCaptureMode() }
    }

    // Riwayat model yang udah dicoba: "MoldDampSeg" (2 kelas, segmentasi) —
    // belum kelar training-nya, skor gak pernah lewat ~3% di gambar apa pun.
    // "MoldDamp" (2 kelas, box doang) — confidence-nya OK (bisa 59%), tapi gak
    // ada mask jadi luas LiDAR dihitung dari box, bukan bentuk noda asli.
    // "Mold" (SEKARANG, 1 kelas single-class + segmentasi) — model paling baru,
    // MoldDetector otomatis baca jumlah kelasnya dari shape tensor (lihat
    // decodeDetections), jadi gak perlu ubah kode lain pas ganti model lagi.
    private let detector = MoldDetector(modelName: "Mold", confidenceThreshold: 0.35)
    /// Rata-rata luminansi (0–1, Rec. 601 luma) yang di-smooth biar
    /// peringatannya gak kelap-kelip tiap tick.
    private var luminanceEMA: Double?
    private var timer: Timer?
    private var isProcessing = false
    private let tickInterval: TimeInterval = 0.4

    /// Berapa tick berturut-turut harus kedeteksi + masuk jangkauan sebelum
    /// dianggap "siap jepret" — ini yang bikin user sempat nahan kameranya dulu.
    /// Sempat diturunin ke 2 (0.8 detik) pas modelnya (MoldDampSeg) belum jalan
    /// sama sekali, jadi belum kerasa efeknya. Sekarang (MoldDamp, kedeteksi
    /// beneran) 2 tick kerasa KETERUSAN CEPET — langsung lompat ke hijau +
    /// auto-capture bikin kaget. Naikin ke 5 (2 detik) biar transisinya kerasa,
    /// gak ujug-ujug.
    private static let requiredStableTicks = 5
    private var stableTicks = 0

    // Jarak efektif sceneDepth LiDAR di iPhone kira-kira segini.
    private static let minRangeMeters: Float = 0.2
    private static let maxRangeMeters: Float = 5.0

    private static let maxDetectionsInPreview = 5

    func start() {
        modelUnavailable = detector == nil
        arSession.start()
        guard arSession.isLiDARSupported else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        setTorch(on: false) // jangan tinggalin lampu nyala pas keluar layar
        arSession.stop()
    }

    // MARK: - Mode & tandai manual

    /// Jalanin ulang sesi AR pas mode berubah. Mode `.manual` nyalain
    /// rekonstruksi mesh LiDAR biar raycast dari layar nabrak permukaan nyata
    /// (bukan bidang datar perkiraan) — itu kunci biar luas polygong yang
    /// dihitung dari koordinat dunia beneran akurat walau bidangnya miring.
    private func applyCaptureMode() {
        guard arSession.isLiDARSupported else { return }
        arSession.applyManualMode(captureMode == .manual)
    }

    /// Poligon sudut (koordinat dunia, meter) -> luas nyata (cm²) pake metode
    /// Newell di ruang 3D. Beda dari ARAreaCalculator yang ngandelin depth map
    /// + intrinsics per-piksel: di sini titiknya udah di dunia nyata, jadi
    /// luasnya langsung dari koordinat 3D, valid buat poligon apa pun (bukan
    /// cuma persegi) dan tahan bidang miring.
    static func polygonAreaCM2(_ points: [SIMD3<Float>]) -> Double? {
        guard points.count >= 3 else { return nil }
        var normal = SIMD3<Float>(0, 0, 0)
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            normal.x += (current.y - next.y) * (current.z + next.z)
            normal.y += (current.z - next.z) * (current.x + next.x)
            normal.z += (current.x - next.x) * (current.y + next.y)
        }
        // simd_length(normal)/2 itu luas dalam m² -> kali 10000 jadi cm².
        return Double(simd_length(normal) / 2) * 10_000
    }

    /// Ambil snapshot foto dari frame ARKit sekarang (sudah di-render tegak),
    /// buat dipakai sebagai `frameImage` temuan tandai manual. Sengaja PAKAI
    /// `capturedImage` (bukan `drawHierarchy` layar) karena `ARSCNView` itu
    /// Metal-backed — `drawHierarchy(in:)` gak bisa nangkep layer Metal, hasilnya
    /// cuma layar hitam di bagian kamera. Ini juga konsisten sama jalur deteksi
    /// otomatis yang juga memakai `capturedImage` (lihat `capture()`).
    func currentFrameSnapshot() -> UIImage? {
        guard let frame = arSession.currentFrame() else { return nil }
        return FrameImageRenderer.uprightCGImage(from: frame.capturedImage).map { UIImage(cgImage: $0) }
    }

    /// Bikin temuan jamur dari tandai manual: snapshot layar jadi foto, luas
    /// dari poligon titik (cm²). `boundingBox` diproyeksikan dari titik dunia ke
    /// koordinat Ternormalisasi layar (origin kiri-atas) pakai intrinsik kamera,
    /// biar kotaknya nempel pas di-overlay Report sama kayak hasil deteksi ML.
    /// Kalau proyeksi gagal, box-nya cuma titik (0,0) — overlay-nya kecil tapi
    /// luas & temuannya tetep valid.
    func buildManualFinding(corners worldPoints: [SIMD3<Float>], snapshot image: UIImage) -> Finding? {
        guard worldPoints.count >= 3 else { return nil }
        guard let areaCM2 = CaptureViewModel.polygonAreaCM2(worldPoints) else { return nil }

        let box: CGRect = {
            guard let frame = arSession.currentFrame() else { return .zero }
            let intrinsics = frame.camera.intrinsics
            let resolution = frame.camera.imageResolution
            let fx = intrinsics[0][0], fy = intrinsics[1][1]
            let cx = intrinsics[2][0], cy = intrinsics[2][1]
            // `camera.transform` itu world = transform * camera. Balik dulu ke
            // ruang kamera sebelum proyeksi: titik dunia langsung dipakai
            // sebagai koordinat kamera itu SALAH (hasilnya melenceng jauh).
            let worldToCamera = frame.camera.transform.inverse
            // Proyeksi tiap titik (sekarang di ruang kamera) -> piksel gambar
            // mentah (landscape), lalu putar ke orientasi tegak (sama kayak
            // `FrameImageRenderer` yang `oriented(.right)`), terakhir normalisasi.
            let projected = worldPoints.map { p -> CGPoint in
                let pc = worldToCamera * SIMD4<Float>(p.x, p.y, p.z, 1)
                // Kamera ARKit right-handed: titik di DEPAN punya Z negatif
                // (lihat ke arah -Z). Pinhole harus membagi dengan |Z| = -pc.z,
                // bukan pc.z — kalau pc.z yang dipakai, hasilnya melenceng jauh
                // DAN tanda X/Y kebalik. Clamp -pc.z biar titik di belakang
                // (Z >= 0, gak seharusnya kejadian) gak bagi nol.
                let z = max(-pc.z, 0.001)
                let px = (CGFloat(pc.x) / CGFloat(z)) * CGFloat(fx) + CGFloat(cx)
                let py = (CGFloat(pc.y) / CGFloat(z)) * CGFloat(fy) + CGFloat(cy)
                // Rotasi 90° CW (raw -> upright, lihat ARAreaCalculator.FrameRotation).
                let ux = 1 - (py / CGFloat(resolution.height))
                let uy = px / CGFloat(resolution.width)
                return CGPoint(x: ux, y: uy)
            }
            let minX = projected.map(\.x).min() ?? 0
            let maxX = projected.map(\.x).max() ?? 0
            let minY = projected.map(\.y).min() ?? 0
            let maxY = projected.map(\.y).max() ?? 0
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }()

        return Finding(
            captureID: UUID(),
            boundingBox: box,
            frameImage: image,
            findingClass: .mold,
            locationNote: Self.locationNote(for: box),
            areaCM2: areaCM2,
            confidence: 1.0,
            isManual: true
        )
    }

    // MARK: - Torch

    func toggleTorch() {
        setTorch(on: !isTorchOn)
    }

    /// ARKit yang pegang capture session-nya, tapi torch itu properti device —
    /// jadi tetap bisa diatur lewat `lockForConfiguration` tanpa ganggu session
    /// ARKit-nya. `hasTorch` dicek dulu: iPad dan Simulator nggak punya.
    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = on
        } catch {
            // Gagal ngunci device — biarin aja, lampu bukan fitur kritis.
            isTorchOn = false
        }
    }

    func retake() {
        captured = nil
        captureError = nil
        resetStability()
    }

    /// Terima foto yang lagi di-preview jadi Finding, lalu balik scan buat titik jamur lain.
    func acceptAndScanAnother() {
        acceptCurrentCapture()
        retake()
    }

    /// Simpan temuan dari tandai manual (dipanggil dari CaptureView saat user
    /// menekan "Save area"). Foto snapshot-nya juga disimpan biar Report tetep
    /// nunjukin foto aslinya — sama kayak jalur deteksi otomatis.
    func acceptManualFinding(_ finding: Finding, photo: UIImage) {
        acceptedFindings.append(finding)
        acceptedPhotos.append(photo)
    }

    struct Outcome {
        let findings: [Finding]
        let photos: [UIImage]
    }

    /// Terima foto yang lagi di-preview (kalau ada), lalu balikin semua Finding
    /// + foto tanpa deteksi yang udah dikumpulin di ruangan ini — dipanggil
    /// pas user tekan Selesai.
    func acceptAndFinish() -> Outcome {
        acceptCurrentCapture()
        return Outcome(findings: acceptedFindings, photos: acceptedPhotos)
    }

    private func acceptCurrentCapture() {
        guard let captured else { return }
        if captured.detections.isEmpty {
            // Gak ada jamur kedeteksi, tapi foto tetep diambil user — simpan
            // fotonya biar tetep bisa ditampilin di Report, bukan cuma dibuang.
            acceptedPhotos.append(captured.image)
        }
        // Satu ID buat SEMUA temuan dari jepretan ini — Report ngelompokin
        // pakai ini, jadi dua titik jamur di satu foto tampil sebagai satu foto
        // dengan dua kotak, bukan dua foto yang sama persis.
        let captureID = UUID()
        for detection in captured.detections {
            acceptedFindings.append(Finding(
                captureID: captureID,
                boundingBox: detection.box,
                frameImage: captured.image,
                findingClass: .mold,
                locationNote: Self.locationNote(for: detection.box),
                areaCM2: detection.areaCM2,
                confidence: Double(detection.confidence)
            ))
        }
        self.captured = nil
    }

    private static func locationNote(for box: CGRect) -> String {
        let vertical: String
        if box.midY < 0.33 {
            vertical = "near the ceiling"
        } else if box.midY > 0.66 {
            vertical = "near the floor"
        } else {
            vertical = "mid-wall"
        }
        if box.midX < 0.33 {
            return "\(vertical), left side"
        } else if box.midX > 0.66 {
            return "\(vertical), right side"
        }
        return vertical
    }

    // MARK: - Scanning

    private func tick() {
        // Pas lagi preview atau lagi proses jepretan, scanning-nya berhenti dulu.
        // Di mode manual gak ada scanning ML — user yang tandain titiknya sendiri,
        // jadi timer deteksi di-skip total.
        guard captured == nil, !isCapturing, !isProcessing, captureMode == .auto,
              let detector, let frame = arSession.currentFrame() else { return }
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            isWaitingForDepth = true
            return
        }
        isWaitingForDepth = false
        isProcessing = true

        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        let imageResolution = frame.camera.imageResolution

        Task.detached(priority: .userInitiated) { [weak self] in
            // Render ke CGImage tegak dulu, baru deteksi di atas situ (lihat
            // catatan di header) — box aja, mask-nya gak perlu di fase ini.
            guard let cgImage = FrameImageRenderer.uprightCGImage(from: pixelBuffer) else {
                await MainActor.run { self?.isProcessing = false }
                return
            }
            let detections = detector.detect(in: cgImage)
            let diagnostics = detector.lastDiagnostics

            let best = detections.max { $0.confidence < $1.confidence }
            var depth: Float?
            if let best {
                depth = ARAreaCalculator.measure(
                    box: best.uiKitBoundingBox,
                    depthMap: depthData.depthMap, confidenceMap: depthData.confidenceMap,
                    intrinsics: intrinsics, imageResolution: imageResolution
                )?.depthMeters
            }

            await MainActor.run {
                guard let self else { return }
                self.updateScanState(detected: best != nil, depth: depth)
                self.updateLighting(cgImage)
                self.debugText = diagnostics
                self.isProcessing = false
            }
        }
    }

    private func updateScanState(detected: Bool, depth: Float?) {
        guard detected else {
            resetStability()
            guidanceText = "Find mold-like objects on surface"
            return
        }
        if let depth, depth < Self.minRangeMeters {
            resetStability()
            guidanceText = "Too close, back up a little"
            return
        }
        if let depth, depth > Self.maxRangeMeters {
            resetStability()
            guidanceText = "Too far, move closer"
            return
        }

        stableTicks += 1
        if stableTicks >= Self.requiredStableTicks {
            phase = .ready
            stabilizeProgress = 1
            // Jepret MANUAL, bukan otomatis. Sebelumnya begitu masuk .ready
            // langsung nembak sendiri, tapi desainnya (Figma 1339:7845) nampilin
            // "Capture now!" plus tombol jepret yang aktif — jadi keputusan
            // motretnya di user. Auto-capture juga bikin kaget dan sering
            // ngambil frame yang belum sesuai maunya user.
            guidanceText = "Capture now!"
        } else {
            phase = .stabilizing
            stabilizeProgress = Double(stableTicks) / Double(Self.requiredStableTicks)
            guidanceText = "Detected, hold the camera steady"
        }
    }

    // MARK: - Lighting

    /// Perbarui `isLightTooDim` dari luminansi frame sekarang. Pakai EMA biar
    /// peringatannya gak kelap-kelip tiap tick (0,4 dtk), plus hysteresis
    /// dikit biar gak bolak-balik pas di ambang.
    private func updateLighting(_ cgImage: CGImage) {
        guard let lum = estimateLuminance(cgImage) else { return }
        let alpha = 0.3
        luminanceEMA = (luminanceEMA ?? lum) * (1 - alpha) + lum * alpha
        guard let avg = luminanceEMA else { return }
        let threshold = 0.12
        let hysteresis = 0.04
        if avg < threshold {
            isLightTooDim = true
        } else if avg > threshold + hysteresis {
            isLightTooDim = false
        }
    }

    /// Estimasi luminansi rata-rata (0–1) dengan cara yang ANDAL: turunin
    /// citra ke 32×32 lewat CGContext, terus rata-ratakan pikselnya (luma
    /// Rec. 601). Pendekatan CIAreaAverage + render(toBitmap:) terbukti
    /// ngasih 0,0 di sini (masalah manajemen warna Core Image), jadi pakai
    /// CGContext aja yang deterministik.
    private func estimateLuminance(_ cgImage: CGImage) -> Double? {
        let size = 32
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: size * size * 4)
        var sum = 0.0
        let n = size * size
        for i in 0..<n {
            let o = i * 4
            sum += 0.299 * Double(ptr[o]) / 255
                 + 0.587 * Double(ptr[o + 1]) / 255
                 + 0.114 * Double(ptr[o + 2]) / 255
        }
        return sum / Double(n)
    }

    private func resetStability() {
        stableTicks = 0
        stabilizeProgress = 0
        phase = .scanning
    }

    // MARK: - Capture

    func capture() {
        guard captured == nil, !isCapturing, let detector, let frame = arSession.currentFrame() else { return }
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            captureError = "LiDAR depth data isn't ready yet. Try again in a moment."
            return
        }
        isCapturing = true
        captureError = nil

        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        let imageResolution = frame.camera.imageResolution

        Task.detached(priority: .userInitiated) { [weak self] in
            // Render ke CGImage tegak dulu (sama kayak di tick()), baru
            // deteksi DI ATAS gambar itu — kali ini pakai mask, hasilnya
            // dipakai buat gambar overlay + hitung luas yang lebih presisi
            // daripada sekadar kotak.
            let cgImage = FrameImageRenderer.uprightCGImage(from: pixelBuffer)
            let instances = cgImage.map { detector.detectWithMasks(in: $0) } ?? []

            var results: [CapturedDetection] = []
            for instance in instances.sorted(by: { $0.confidence > $1.confidence }).prefix(Self.maxDetectionsInPreview) {
                let box = CGRect(
                    x: instance.boundingBox.minX,
                    y: 1 - instance.boundingBox.maxY,
                    width: instance.boundingBox.width,
                    height: instance.boundingBox.height
                )
                let hasMask = instance.maskPixelCount > 0
                let measurement = hasMask
                    ? ARAreaCalculator.measure(
                        mask: instance, depthMap: depthData.depthMap, confidenceMap: depthData.confidenceMap,
                        intrinsics: intrinsics, imageResolution: imageResolution)
                    : ARAreaCalculator.measure(
                        box: box, depthMap: depthData.depthMap, confidenceMap: depthData.confidenceMap,
                        intrinsics: intrinsics, imageResolution: imageResolution)

                var areaText: String?
                var note: String?
                if let measurement {
                    if measurement.depthMeters < Self.minRangeMeters {
                        note = "too close, area is less accurate"
                    } else if measurement.depthMeters > Self.maxRangeMeters {
                        note = "too far for LiDAR, area is less accurate"
                    }
                    areaText = String(format: "%.0f cm²", measurement.areaCM2)
                } else {
                    note = "couldn't read depth in this area"
                }

                results.append(CapturedDetection(
                    box: box, mask: hasMask ? instance : nil, confidence: instance.confidence,
                    areaCM2: measurement?.areaCM2, areaText: areaText, note: note
                ))
            }

            await MainActor.run {
                guard let self else { return }
                self.isCapturing = false
                guard let cgImage else {
                    self.captureError = "Couldn't capture an image from the camera."
                    return
                }
                self.captured = CapturedResult(image: UIImage(cgImage: cgImage), detections: results)
            }
        }
    }
}
