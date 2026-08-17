//
//  AnalyzingLoadingView.swift
//  HoMoold
//
//  Layar "Loading Page" di Figma (1335:5576) — jembatan antara kamera dan
//  report. Latarnya `#f7f7f7`, wordmark hoomold di atas, spinner di tengah,
//  caption abu-abu 2 baris di bawah.
//
//  Di sinilah `resultInspection` dirakit (lihat
//  InspectionFlowState.buildResultInspection) — dulu kerjaannya
//  ConditionFormView, sebelum form kondisi pindah ke sebelum kamera.
//
//  Deteksi jamurnya sendiri udah kelar duluan di CaptureView (jalan live per
//  frame), jadi di sini nggak ada kerjaan berat. Delay-nya cuma biar transisi ke
//  report nggak kedip — plus ngasih waktu buat kebaca disclaimer AI-nya.
//

import SwiftUI

struct AnalyzingLoadingView: View {
    @ObservedObject var flow: InspectionFlowState

    /// Sengaja pendek — cuma nutup transisi, bukan nunggu kerjaan nyata.
    private let minimumDisplayDuration: Duration = .milliseconds(900)

    var body: some View {
        ZStack {
            Theme.color.surfaceMuted
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Figma: wordmark lebar 274pt, 85pt dari atas.
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 274)
                    .padding(.top, 24)
                    .accessibilityLabel("HooMold")

                Spacer()

                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)

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
            flow.buildResultInspection()
            try? await Task.sleep(for: minimumDisplayDuration)
            guard flow.resultInspection != nil else { return }
            // GANTI path, jangan append: kalau loading ditinggal di stack, balik
            // dari report bakal mendarat di sini dan `task` jalan lagi — langsung
            // kelempar ke report terus, nggak bisa keluar.
            flow.path = [.report]
        }
    }
}

#Preview {
    let property = KosProperty(name: "Sample House", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        AnalyzingLoadingView(flow: InspectionFlowState(existingProperty: property))
    }
}
