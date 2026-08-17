//
//  GuidanceView.swift
//  HoMoold
//
//  Layar "Guidance Page (2 Step)" di Figma (1339:7252 & 1339:7270) — carousel
//  2 halaman yang ngajarin cara motret, muncul pas kamera mau dibuka.
//
//  Layar ini SATU-SATUNYA surface gelap di app (app-nya dipaksa light mode).
//  Latarnya foto ruangan yang diredupin, teks putih. Makanya di sini nggak boleh
//  pakai Color.primary/.secondary — lihat catatan di Theme.color.textOnDark.
//

import SwiftUI

struct GuidanceView: View {
    @ObservedObject var flow: InspectionFlowState

    @State private var pageIndex = 0

    private let pages = GuidancePage.all

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                // Carousel manual — `TabView(.page)` nggak mau pindah halaman
                // waktu index-nya diubah dari tombol Continue. Lihat catatan di
                // PagedCarousel.
                PagedCarousel(items: pages, index: $pageIndex) { page in
                    GuidancePageView(page: page)
                }

                PageDots(
                    count: pages.count,
                    index: pageIndex,
                    activeColor: Theme.color.textOnDark,
                    inactiveColor: Theme.color.textOnDark.opacity(0.35)
                )
                .padding(.bottom, 18)

                Button("What does mold look like?") {
                    flow.path.append(.moldReference)
                }
                .font(Theme.font.footnote)
                .foregroundStyle(Theme.color.textOnDarkSecondary)
                .padding(.bottom, 18)

                Button(isLastPage ? "Open camera" : "Continue") { advance() }
                    .buttonStyle(.pillProminent)
                    .padding(.horizontal, Theme.Metric.guidanceHorizontalPadding)
            }
            // Jarak tetap 28pt DI ATAS safe area — `safeAreaPadding` doang
            // ternyata masih bikin tombolnya mepet home indicator.
            .padding(.bottom, 28)
            .safeAreaPadding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Foto ruangan + scrim.
    ///
    /// Tiap lapis dikasih `.ignoresSafeArea()` SENDIRI-SENDIRI. Sebelumnya
    /// scrim-nya dipasang sebagai `.overlay` di atas Image lalu baru
    /// `.ignoresSafeArea()` di paling akhir — hasilnya scrim ke-compose duluan
    /// di ukuran yang masih kena safe area, jadi bagian atas layar (area status
    /// bar) nggak keredupin dan keliatan kepotong.
    private var background: some View {
        ZStack {
            Color.black

            Image("GuidanceBackground")
                .resizable()
                .scaledToFill()

            Theme.gradient.guidanceScrim
        }
        .ignoresSafeArea()
    }

    private var isLastPage: Bool { pageIndex >= pages.count - 1 }

    private func advance() {
        if isLastPage {
            flow.path.append(.capture)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                pageIndex += 1
            }
        }
    }
}

// MARK: - Page model

/// Copy diambil verbatim dari Figma — termasuk yang gramatikanya nyeleneh
/// ("get closed"), biar nggak beda sama desain.
struct GuidancePage: Identifiable {
    let id = UUID()
    var illustration: String
    var title: String
    var subtitle: String

    /// DUA halaman — sesuai nama frame-nya di Figma, "(2 Step)". Perbandingan
    /// Mold/Mildew/Dampness ada di layar sendiri (MoldReferenceView).
    static let all: [GuidancePage] = [
        GuidancePage(
            illustration: "GuidanceStep1",
            title: "Look around for any visible mold",
            subtitle: "if you find some get closed and take a photo"
        ),
        GuidancePage(
            illustration: "GuidanceStep2",
            title: "No mold exist in the room",
            subtitle: "you can skip and fill the checkbox on the next step"
        ),
    ]
}

// MARK: - Single page

private struct GuidancePageView: View {
    let page: GuidancePage

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(page.illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 32)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(Theme.font.title2)
                    .foregroundStyle(Theme.color.textOnDark)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textOnDarkSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Metric.guidanceHorizontalPadding)
    }
}

#Preview {
    let property = KosProperty(name: "Sample House", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        GuidanceView(flow: InspectionFlowState(existingProperty: property))
    }
}
