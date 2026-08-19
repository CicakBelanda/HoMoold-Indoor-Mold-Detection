//
//  DragRectangleOverlay.swift
//  HoMoold
//
//  Overlay drag-select buat mode Manual di layar kamera. User tahan lalu geser
//  buat gambar kotak area jamur — persis kayak drag-select di editor foto.
//  Koordinatnya normalized (0–1, origin kiri-atas) biar SAMA dengan ruang
//  `CapturedDetection.boundingBox` / `Finding.boundingBox` (lihat
//  CaptureViewModel.commitManualBox), jadi luas & overlay Report langsung
//  cocok tanpa konversi tambahan.
//

import SwiftUI

/// Kotak yang lagi di-drag, dalam koordinat normalized layar (0–1).
private struct DragRect: Equatable {
    var origin: CGPoint
    var current: CGPoint

    var cgRect: CGRect {
        // Selalu jadi CGRect valid (min/max) walau di-drag ke arah kiri/atas.
        let minX = min(origin.x, current.x)
        let maxX = max(origin.x, current.x)
        let minY = min(origin.y, current.y)
        let maxY = max(origin.y, current.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct DragRectangleOverlay: View {
    /// Dipanggil pas user lepas jari, bawa kotak normalized (0–1) yang udah
    /// dibatasi minimal ukuran — `nil` kalau kotaknya kekecilan (dianggap
    /// kebetulan sentuh, gak jadi commit).
    var onCommit: (CGRect?) -> Void

    @State private var drag: DragRect?
    /// Batas minimal sisi kotak (normalized) biar gak kecil banget pas cuma
    /// kebetulan nyentuh layar.
    private let minimumSide: CGFloat = 0.04

    var body: some View {
        GeometryReader { geo in
            content(geo: geo)
        }
        // `allowsHitTesting` di-overlay transparan ini aktif di mode Manual;
        // di mode Auto overlay ini gak dipasang sama sekali (lihat CaptureView).
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func content(geo: GeometryProxy) -> some View {
        ZStack {
            // Lapisan transparan penangkap gesture — penuh layar.
            Color.clear
                .contentShape(Rectangle())
                .gesture(panGesture(geo: geo))

            // Gambar kotak kuning HIDUP selagi di-drag.
            if let drag {
                let r = drag.cgRect
                Rectangle()
                    .stroke(Theme.color.riskMedium, lineWidth: 3)
                    .background(Theme.color.riskMedium.opacity(0.12))
                    .frame(width: geo.size.width * r.width, height: geo.size.height * r.height)
                    .position(x: geo.size.width * (r.minX + r.width / 2),
                              y: geo.size.height * (r.minY + r.height / 2))
            }
        }
    }

    private func panGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let start = clamp(value.startLocation, in: geo)
                let cur = clamp(value.location, in: geo)
                drag = DragRect(origin: start, current: cur)
            }
            .onEnded { value in
                let start = clamp(value.startLocation, in: geo)
                let cur = clamp(value.location, in: geo)
                let rect = DragRect(origin: start, current: cur).cgRect
                // Terlalu kecil = kebetulan nyentuh, gak di-commit.
                if rect.width < minimumSide || rect.height < minimumSide {
                    drag = nil
                    onCommit(nil)
                } else {
                    onCommit(rect)
                    // Biarin `captured` yang tampil — overlay ini otomatis
                    // ilang karena CaptureView cuma pasangnya pas
                    // `viewModel.captured == nil`.
                    drag = nil
                }
            }
    }

    /// Clamp titik ke dalam [0,1]×[0,1] biar kotak gak keluar layar.
    private func clamp(_ point: CGPoint, in geo: GeometryProxy) -> CGPoint {
        guard geo.size.width > 0, geo.size.height > 0 else { return .zero }
        let x = min(max(point.x / geo.size.width, 0), 1)
        let y = min(max(point.y / geo.size.height, 0), 1)
        return CGPoint(x: x, y: y)
    }
}
