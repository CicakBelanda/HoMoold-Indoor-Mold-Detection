//
//  MaskOverlayView.swift
//  HoMoold
//
//  Overlay mask segmentasi (biner, per piksel) di atas frame kamera — analog
//  BoundingBoxOverlay tapi bukan kotak. Mask dianggap menutupi seluruh frame
//  secara ternormalisasi (lihat SegmentationInstance), jadi cukup di-stretch
//  ke ukuran view yang nampilin frame yang sama — gak perlu tahu resolusi/
//  aspect ratio asli capturedImage.
//

import SwiftUI

struct MaskOverlayView: View {
    let instances: [SegmentationInstance]

    var body: some View {
        GeometryReader { geo in
            ForEach(instances) { instance in
                if let cgImage = MaskRenderer.image(for: instance) {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

enum MaskRenderer {
    private static let alpha: Float = 0.5

    /// Warna merah buat mold (satu-satunya kelas yang dipakai sekarang, lihat MoldDetector).
    private static func color(for label: String) -> (r: UInt8, g: UInt8, b: UInt8) {
        label == "mold" ? (214, 69, 65) : (222, 149, 45)
    }

    static func image(for instance: SegmentationInstance) -> CGImage? {
        let width = instance.maskWidth
        let height = instance.maskHeight
        guard width > 0, height > 0 else { return nil }

        let base = color(for: instance.label)
        // Premultiplied alpha — data ditulis langsung ke buffer, bukan lewat CGContext draw,
        // jadi channel RGB harus udah dikali alpha sendiri.
        let r = UInt8(Float(base.r) * alpha)
        let g = UInt8(Float(base.g) * alpha)
        let b = UInt8(Float(base.b) * alpha)
        let a = UInt8(alpha * 255)

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                guard instance.maskValue(x: x, y: y) else { continue }
                let offset = (y * width + x) * 4
                pixels[offset] = r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = a
            }
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return context.makeImage()
    }
}

#Preview {
    let mask: [Bool] = (0..<40 * 40).map { i in
        let x = i % 40, y = i / 40
        return (x - 20) * (x - 20) + (y - 20) * (y - 20) < 12 * 12
    }
    return ZStack {
        Color.gray.opacity(0.3)
        MaskOverlayView(instances: [
            SegmentationInstance(label: "mold", confidence: 0.8, boundingBox: .zero, mask: mask, maskWidth: 40, maskHeight: 40)
        ])
    }
    .frame(width: 300, height: 300)
}
