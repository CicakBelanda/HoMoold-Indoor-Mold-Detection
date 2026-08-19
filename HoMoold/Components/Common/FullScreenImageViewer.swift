//
//  FullScreenImageViewer.swift
//  HoMoold
//
//  Tampilan full-screen buat foto temuan di Report — pinch buat zoom, geser
//  pas di-zoom, double-tap buat zoom cepat, tombol X buat tutup.
//

import SwiftUI

struct FullScreenImageViewer: View {
    let image: UIImage
    /// Kotak deteksi yang ikut digambar di atas foto. Kosong = foto polos.
    /// Ikut di-zoom & digeser bareng fotonya, jadi kotaknya tetap nempel di
    /// tempat yang bener.
    var findings: [Finding] = []
    /// Kalau diisi, tombol hapus muncul di bawah. Hapus-nya ditaruh DI SINI,
    /// bukan di menu "..." halaman Report — di menu, user harus inget dulu foto
    /// mana yang lagi kebuka; di preview, yang dihapus persis yang lagi dilihat.
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Gambar + kotak dibungkus SATU ZStack ber-aspect-ratio sama dengan
            // fotonya, terus zoom/offset dipasang ke bungkusnya — kalau kotaknya
            // di-transform terpisah, posisinya bakal melenceng pas di-zoom.
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                ForEach(findings) { finding in
                    MoldDetectionBox(boundingBox: finding.boundingBox)
                }
            }
            .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(1, lastScale * value), 4)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale == 1 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if scale > 1 {
                            scale = 1
                            lastScale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
        }
        // Tombol tutup: kaca sistem bentuk lingkaran, sama persis kayak tombol
        // X di layar kamera. Dulu cuma glyph `xmark.circle.fill` polos yang
        // ngandelin lingkaran bawaan simbolnya sebagai "latar".
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            // `.black` literal, BUKAN `.primary`. App ini dikunci light mode
            // (lihat HoMooldApp), jadi sekarang dua-duanya sama-sama hitam —
            // tapi kalau dark mode suatu saat dibuka, `.primary` bakal balik
            // jadi putih dan ngebatalin permintaan ini diam-diam.
            .tint(.black)
            .padding(20)
            .accessibilityLabel("Close")
        }
        .overlay(alignment: .bottom) {
//            if onDelete != nil {
//                // Kaca ber-tint merah, bukan kapsul merah yang digambar sendiri.
//                // Tetap merah karena ini aksi destruktif — yang berubah cuma
//                // siapa yang menggambar latarnya.
//                Button(role: .destructive) {
//                    showDeleteConfirm = true
//                } label: {
//                    Label("Delete photo", systemImage: "trash")
//                }
//                .buttonStyle(.glassProminent)
//                .buttonBorderShape(.capsule)
//                .controlSize(.large)
//                .tint(Theme.color.riskHigh)
//                .padding(.bottom, 28)
//                .safeAreaPadding(.bottom)
//            }
        }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Photo", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo and its detection will be removed from the report.")
        }
    }
}

#Preview {
    FullScreenImageViewer(image: PlaceholderImageFactory.roomImage(for: .bedroom, seed: 1))
}
