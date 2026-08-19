//
//  GuidanceView.swift
//  HoMoold
//
//  Layar "Guidance Page" di Figma (1058:3012) — satu halaman yang ngajarin cara
//  motret, muncul pas kamera mau dibuka.
//
//  Dulu carousel 2 halaman. Halaman keduanya ("No mold exist in the room —
//  you can skip and fill the checkbox on the next step") dibuang: layar ini
//  cuma kebuka kalau user UDAH nyentang "Visible Mold" di form kondisi, jadi
//  halaman yang ngajarin cara bilang "nggak ada jamur" nggak pernah relevan
//  buat orang yang lagi lihat halaman ini.
//
//  Layar ini SATU-SATUNYA surface gelap di app (app-nya dipaksa light mode).
//  Latarnya foto ruangan yang diredupin, teks putih. Makanya di sini nggak boleh
//  pakai Color.primary/.secondary — lihat catatan di Theme.color.textOnDark.
//

import SwiftUI

struct GuidanceView: View {
    @ObservedObject var flow: InspectionFlowState

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                // Satu halaman — carousel, titik halaman, dan state indeksnya
                // ikut dibuang. PagedCarousel-nya sendiri masih kepakai di
                // ReportView, jadi komponennya tetap ada.
                GuidancePageView(page: .step)

                Button("What does mold look like?") {
                    flow.path.append(.moldReference)
                }
                .font(Theme.font.footnote)
                .foregroundStyle(Theme.color.textOnDarkSecondary)
                .padding(.bottom, 18)

                Button("Open camera") { flow.path.append(.capture) }
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

}

// MARK: - Page model

/// Copy diambil verbatim dari Figma — termasuk yang gramatikanya nyeleneh
/// ("get closed"), biar nggak beda sama desain.
struct GuidancePage {
    var illustration: String
    var title: String
    var subtitle: String

    /// Satu-satunya halaman. Perbandingan Mold vs Dampness ada di layar sendiri
    /// (MoldReferenceView), dijangkau lewat tautan di bawah ilustrasi.
    static let step = GuidancePage(
        illustration: "GuidanceIllustration",
        title: "Look around for any visible mold",
        subtitle: "if you find some get closed and take a photo"
    )
}

// MARK: - Single page

private struct GuidancePageView: View {
    let page: GuidancePage

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // `.screen` — ilustrasinya digambar DI ATAS latar hitam pekat
            // (alpha 1.0, bukan transparan; udah dicek per-piksel). Kalau
            // ditaruh apa adanya di layar ini, yang muncul kotak hitam
            // bertepi tajam di atas foto ruangan yang jadi latar.
            //
            // Blend `.screen` bikin hitam murni jadi nggak ngaruh apa-apa
            // (hasilnya = warna latar), sementara bagian terang ilustrasinya
            // tetap terang. Jadi latar hitamnya hilang sendiri tanpa perlu
            // ngedit asetnya. Kalau suatu saat asetnya diganti versi yang
            // latarnya beneran transparan, baris ini bisa dibuang.
            Image(page.illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .blendMode(.screen)

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
