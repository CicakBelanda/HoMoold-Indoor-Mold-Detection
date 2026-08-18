//
//  PagedCarousel.swift
//  HoMoold
//
//  Carousel manual: HStack yang digeser pakai offset, bukan `TabView`.
//
//  Kenapa bukan TabView: `TabView` + `.tabViewStyle(.page)` sering nggak nurut
//  waktu selection-nya diubah dari KODE (mis. dari tombol Continue/panah) —
//  swipe manual jalan, tapi ganti index programatik diem aja. Sudah dicoba dua
//  kali dengan tag/id yang beda dan tetap nyangkut, jadi paging-nya diambil
//  alih sendiri di sini: posisinya murni fungsi dari `index`, nggak ada state
//  internal yang bisa nggak sinkron.
//
//  Bonus: `peek` bikin halaman berikutnya nongol dikit di tepi — itu yang
//  ngasih tau user masih ada isi lain di sebelah, tanpa perlu tulisan.
//

import SwiftUI

struct PagedCarousel<Item, Content: View>: View {
    let items: [Item]
    /// Berapa lebar halaman berikutnya yang nongol di tepi. 0 = satu halaman
    /// penuh tanpa intipan.
    var peek: CGFloat = 0
    var spacing: CGFloat = 12
    @Binding var index: Int
    @ViewBuilder let content: (Item) -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(geo.size.width - peek, 1)
            let step = pageWidth + spacing

            HStack(spacing: spacing) {
                ForEach(items.indices, id: \.self) { i in
                    content(items[i])
                        .frame(width: pageWidth)
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
            .offset(x: -CGFloat(clampedIndex) * step + dragOffset)
            .animation(.easeInOut(duration: 0.28), value: clampedIndex)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        // Ambang seperlima lebar halaman — cukup ringan biar
                        // geseran pendek tetap kebaca sebagai ganti halaman.
                        let threshold = pageWidth / 5
                        var target = clampedIndex
                        if value.translation.width < -threshold { target += 1 }
                        if value.translation.width > threshold { target -= 1 }

                        dragOffset = 0
                        withAnimation(.easeInOut(duration: 0.28)) {
                            index = min(max(target, 0), items.count - 1)
                        }
                    }
            )
        }
    }

    private var clampedIndex: Int {
        min(max(index, 0), max(items.count - 1, 0))
    }
}

/// Titik indikator halaman.
struct PageDots: View {
    let count: Int
    let index: Int
    var activeColor: Color = Theme.color.brand
    var inactiveColor: Color = Theme.color.textSecondary.opacity(0.3)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Circle()
                    .fill(i == index ? activeColor : inactiveColor)
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}
