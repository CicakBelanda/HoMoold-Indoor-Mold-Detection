//
//  PlaceholderImageFactory.swift
//  HoMoold
//
//  Menghasilkan ilustrasi kamar sederhana secara prosedural (bukan foto asli)
//  supaya data dummy tidak butuh aset gambar. Cukup untuk preview UI.
//

import UIKit

enum PlaceholderImageFactory {

    private static let palettes: [(top: UIColor, bottom: UIColor, wall: UIColor)] = [
        (UIColor(red: 0.96, green: 0.86, blue: 0.72, alpha: 1), UIColor(red: 0.89, green: 0.71, blue: 0.52, alpha: 1), UIColor(red: 0.93, green: 0.80, blue: 0.64, alpha: 1)),
        (UIColor(red: 0.90, green: 0.84, blue: 0.87, alpha: 1), UIColor(red: 0.76, green: 0.66, blue: 0.72, alpha: 1), UIColor(red: 0.85, green: 0.78, blue: 0.81, alpha: 1)),
        (UIColor(red: 0.85, green: 0.90, blue: 0.86, alpha: 1), UIColor(red: 0.65, green: 0.76, blue: 0.68, alpha: 1), UIColor(red: 0.80, green: 0.86, blue: 0.82, alpha: 1)),
        (UIColor(red: 0.93, green: 0.90, blue: 0.80, alpha: 1), UIColor(red: 0.80, green: 0.74, blue: 0.58, alpha: 1), UIColor(red: 0.90, green: 0.87, blue: 0.76, alpha: 1)),
    ]

    static func roomImage(for roomType: RoomType, seed: Int, size: CGSize = CGSize(width: 480, height: 480)) -> UIImage {
        let palette = palettes[abs(seed) % palettes.count]
        let mirrored = abs(seed) % 2 == 0

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Wall gradient background
            let colors = [palette.top.cgColor, palette.bottom.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            // Floor
            let floorRect = CGRect(x: 0, y: size.height * 0.78, width: size.width, height: size.height * 0.22)
            UIColor(red: 0.55, green: 0.38, blue: 0.27, alpha: 1).setFill()
            UIBezierPath(rect: floorRect).fill()

            // Window
            let windowX = mirrored ? size.width * 0.62 : size.width * 0.08
            let windowRect = CGRect(x: windowX, y: size.height * 0.12, width: size.width * 0.3, height: size.height * 0.38)
            let windowPath = UIBezierPath(roundedRect: windowRect, cornerRadius: 6)
            UIColor(red: 0.98, green: 0.93, blue: 0.78, alpha: 1).setFill()
            windowPath.fill()
            UIColor.white.withAlphaComponent(0.9).setStroke()
            windowPath.lineWidth = 4
            windowPath.stroke()
            let cross = UIBezierPath()
            cross.move(to: CGPoint(x: windowRect.midX, y: windowRect.minY))
            cross.addLine(to: CGPoint(x: windowRect.midX, y: windowRect.maxY))
            cross.move(to: CGPoint(x: windowRect.minX, y: windowRect.midY))
            cross.addLine(to: CGPoint(x: windowRect.maxX, y: windowRect.midY))
            cross.lineWidth = 3
            UIColor.white.withAlphaComponent(0.9).setStroke()
            cross.stroke()

            // Sun glow near window
            let glowCenter = CGPoint(x: windowRect.midX, y: windowRect.midY)
            if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor.white.withAlphaComponent(0.6).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 1]) {
                cg.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: size.width * 0.28, options: [])
            }

            // Bed / fixture depending on room type
            switch roomType {
            case .bedroom, .livingRoom:
                let bedRect = CGRect(x: size.width * 0.06, y: size.height * 0.58, width: size.width * 0.7, height: size.height * 0.24)
                let bedPath = UIBezierPath(roundedRect: bedRect, cornerRadius: 14)
                UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1).setFill()
                bedPath.fill()
                let pillow1 = CGRect(x: bedRect.minX + 12, y: bedRect.minY - 14, width: bedRect.width * 0.28, height: 28)
                let pillow2 = CGRect(x: bedRect.minX + 12 + bedRect.width * 0.32, y: bedRect.minY - 14, width: bedRect.width * 0.28, height: 28)
                UIColor.white.setFill()
                UIBezierPath(roundedRect: pillow1, cornerRadius: 10).fill()
                UIBezierPath(roundedRect: pillow2, cornerRadius: 10).fill()
            case .bathroom:
                let tubRect = CGRect(x: size.width * 0.1, y: size.height * 0.56, width: size.width * 0.55, height: size.height * 0.2)
                UIColor.white.withAlphaComponent(0.95).setFill()
                UIBezierPath(roundedRect: tubRect, cornerRadius: 18).fill()
            case .kitchen:
                let counterRect = CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.18)
                UIColor(red: 0.88, green: 0.88, blue: 0.9, alpha: 1).setFill()
                UIBezierPath(rect: counterRect).fill()
            }

            // Plant accent
            let plantX = mirrored ? size.width * 0.1 : size.width * 0.82
            drawPlant(in: cg, at: CGPoint(x: plantX, y: size.height * 0.5))

            palette.wall.withAlphaComponent(0.0).setFill() // no-op keeps palette referenced
        }
    }

    private static func drawPlant(in cg: CGContext, at point: CGPoint) {
        UIColor(red: 0.35, green: 0.5, blue: 0.32, alpha: 1).setFill()
        for i in 0..<4 {
            let angle = CGFloat(i) * (.pi / 5) - .pi / 4
            let leafEnd = CGPoint(x: point.x + cos(angle) * 26, y: point.y - abs(sin(angle)) * 34)
            let path = UIBezierPath()
            path.move(to: point)
            path.addQuadCurve(to: leafEnd, controlPoint: CGPoint(x: point.x + cos(angle) * 10, y: point.y - 20))
            path.addQuadCurve(to: point, controlPoint: CGPoint(x: point.x + cos(angle) * 30, y: point.y - 10))
            path.close()
            path.fill()
        }
    }

    /// Frame temuan: gambar kamar ditambah bercak noda samar di lokasi tertentu,
    /// supaya kelihatan "sebab" bounding box-nya muncul di situ.
    static func findingFrame(for roomType: RoomType, seed: Int, stainAt normalizedCenter: CGPoint, findingClass: FindingClass, size: CGSize = CGSize(width: 480, height: 480)) -> UIImage {
        let base = roomImage(for: roomType, seed: seed, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            base.draw(at: .zero)
            let cg = ctx.cgContext
            let center = CGPoint(x: normalizedCenter.x * size.width, y: normalizedCenter.y * size.height)
            let stainColor: UIColor = findingClass == .crack
                ? UIColor(white: 0.25, alpha: 0.35)
                : UIColor(red: 0.42, green: 0.36, blue: 0.22, alpha: 0.35)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: [stainColor.cgColor, stainColor.withAlphaComponent(0).cgColor] as CFArray,
                                          locations: [0, 1]) {
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 46, options: [])
            }
        }
    }
}
