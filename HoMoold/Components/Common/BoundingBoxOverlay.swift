//
//  BoundingBoxOverlay.swift
//  HoMoold
//

import SwiftUI

/// Menggambar kotak label deteksi (mis. "MOLD") di atas foto/frame, dengan
/// `boundingBox` dalam koordinat ternormalisasi (0-1) relatif ke ukuran frame.
struct BoundingBoxOverlay: View {
    let label: String
    let color: Color
    let boundingBox: CGRect

    init(findingClass: FindingClass, boundingBox: CGRect) {
        self.label = findingClass.rawValue
        self.color = findingClass.color
        self.boundingBox = boundingBox
    }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: boundingBox.minX * geo.size.width,
                y: boundingBox.minY * geo.size.height,
                width: boundingBox.width * geo.size.width,
                height: boundingBox.height * geo.size.height
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(color, lineWidth: 2.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .position(x: rect.minX + 24, y: max(rect.minY - 10, 10))
            }
            .accessibilityLabel("Detected \(label)")
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        BoundingBoxOverlay(findingClass: .mold, boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.25))
    }
    .frame(width: 300, height: 300)
}
