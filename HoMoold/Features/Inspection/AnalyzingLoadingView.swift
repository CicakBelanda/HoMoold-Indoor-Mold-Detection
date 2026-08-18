//
//  AnalyzingLoadingView.swift
//  HoMoold
//
//  Layar "Loading Page" di Figma (1335:5576) — jembatan antara kamera dan
//  report. Latarnya `#f7f7f7`, wordmark hoomold di atas, caption abu-abu 2 baris
//  di bawah.
//
//  Di sinilah `resultInspection` dirakit (lihat
//  InspectionFlowState.buildResultInspection) — dulu kerjaannya
//  ConditionFormView, sebelum form kondisi pindah ke sebelum kamera.
//
//  Deteksi jamurnya sendiri udah kelar duluan di CaptureView (jalan live per
//  frame), jadi di sini nggak ada kerjaan berat. Delay-nya cuma biar transisi ke
//  report nggak kedip — plus ngasih waktu buat kebaca disclaimer AI-nya.
//
//  Indikator loading-nya wordmark itu sendiri: mulai abu-abu, lalu warnanya
//  naik dari bawah ke atas sampai penuh. Spinner bundar bawaan dibuang — dua
//  indikator di satu layar bikin mata bingung harus lihat yang mana, dan
//  spinner generik nggak ngasih apa-apa yang logo ini nggak bisa kasih.
//

import SwiftUI

struct AnalyzingLoadingView: View {
    @ObservedObject var flow: InspectionFlowState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 = abu-abu semua, 1 = kewarnain penuh.
    @State private var fillLevel: CGFloat = 0

    /// Lama layar ini nongol. Ini MURNI jeda buatan — kerjaan beratnya
    /// (deteksi jamur) udah kelar duluan di CaptureView, dan
    /// `buildResultInspection()` di bawah cuma ngerakit struct plus sekali
    /// panggil RiskClassifier, hitungan milidetik.
    ///
    /// Jadi angkanya ditentuin dari sisi tampilan, bukan dari kerjaan: 900ms
    /// (versi awal) kependekan buat animasi isi logonya kebaca, 1,6 detik pas,
    /// dan sekarang 3,6 detik biar gerakannya sempat ditonton dan disclaimer
    /// AI-nya sempat kebaca sampai habis.
    ///
    /// Durasi animasi logonya ngikut nilai ini otomatis (lihat `fillDuration`),
    /// jadi kalau mau dipercepat/diperlambat cukup ubah di sini.
    private let minimumDisplayDuration: Duration = .milliseconds(2600)

    /// Figma: wordmark lebar 274pt. Tingginya diturunin dari rasio aset aslinya
    /// (3611×775) — dipatok eksplisit karena mask di bawah butuh tinggi yang
    /// pasti, dan `scaledToFit` doang nggak ngasih tau berapa.
    private let logoWidth: CGFloat = 274
    private var logoHeight: CGFloat { logoWidth * 775 / 3611 }

    private var fillDuration: TimeInterval {
        Double(minimumDisplayDuration.components.seconds)
            + Double(minimumDisplayDuration.components.attoseconds) / 1e18
    }

    var body: some View {
        ZStack {
            Theme.color.surfaceMuted
                .ignoresSafeArea()

            // Logo DI TENGAH layar, caption tetap nempel di bawah.
            //
            // Sengaja dua lapis ZStack, bukan satu VStack dengan Spacer atas
            // dan bawah: dengan VStack, tinggi caption ikut ngitung, jadi
            // logonya kedorong naik dan nggak pernah bener-bener di tengah.
            // Di sini logonya ditengahin sama ZStack tanpa peduli ada apa di
            // bawahnya.
            logo

            VStack(spacing: 0) {
                Spacer()

                // Figma: `#6e6e6e`, 16pt, dua baris, rata tengah.
                Text("Please wait, AI is processing the report...\nJust a heads-up: AI can hallucinate. Stay sharp!")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            startFilling()
            flow.buildResultInspection()
            try? await Task.sleep(for: minimumDisplayDuration)
            guard flow.resultInspection != nil else { return }
            // GANTI path, jangan append: kalau loading ditinggal di stack, balik
            // dari report bakal mendarat di sini dan `task` jalan lagi — langsung
            // kelempar ke report terus, nggak bisa keluar.
            flow.path = [.report]
        }
    }

    // MARK: - Logo

    /// Dua salinan logo yang ditumpuk: yang bawah abu-abu pucat (selalu penuh),
    /// yang atas berwarna tapi ditutup mask yang tumbuh dari bawah.
    ///
    /// Sengaja pakai `.grayscale()` + mask, BUKAN `.renderingMode(.template)` +
    /// dua warna: aset logonya PNG berwarna, bukan glyph satu warna, jadi kalau
    /// dijadiin template semua detailnya rata jadi satu blok.
    @ViewBuilder
    private var logo: some View {
        if reduceMotion {
            // Reduce Motion nyala — jangan ada yang gerak. Logonya utuh, dan
            // indikator "lagi jalan"-nya balik ke spinner sistem yang memang
            // dikecualikan dari aturan itu.
            VStack(spacing: 20) {
                logoImage
                    .frame(width: logoWidth, height: logoHeight)

                ProgressView()
                    .progressViewStyle(.circular)
            }
            .accessibilityElement()
            .accessibilityLabel("HooMold, processing the report")
        } else {
            ZStack {
                logoImage
                    .grayscale(1)
                    .opacity(0.3)

                logoImage
                    .mask(alignment: .bottom) {
                        // Tepi atasnya dibikin melunak, bukan garis lurus —
                        // batas yang tajam di wordmark setipis ini kebaca kayak
                        // gambarnya kepotong, bukan kayak lagi keisi.
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.8),
                                .init(color: .white.opacity(0), location: 1),
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: logoHeight * fillLevel)
                    }
            }
            .frame(width: logoWidth, height: logoHeight)
            .accessibilityElement()
            .accessibilityLabel("HooMold, processing the report")
        }
    }

    private var logoImage: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
    }

    /// Isinya naik sekali dari 0 ke penuh, pas selama layar ini nongol — jadi
    /// begitu penuh, halamannya pindah. Sengaja BUKAN animasi berulang: kalau
    /// ngulang, user baca itu sebagai "masih lama", padahal justru sebaliknya.
    private func startFilling() {
        guard !reduceMotion else { return }
        fillLevel = 0
        withAnimation(.easeInOut(duration: fillDuration)) {
            fillLevel = 1
        }
    }
}

#Preview {
    let property = KosProperty(name: "Sample House", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        AnalyzingLoadingView(flow: InspectionFlowState(existingProperty: property))
    }
}
