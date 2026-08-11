//
//  GuidedInstructionBar.swift
//  HoMoold
//
//  Bar instruksi live di atas layar rekam — ganti step otomatis berdasar hasil
//  deteksi asli (bukan timer tetap). Jumlah titik progress ngikutin jumlah
//  step di GuidedRecordingController.
//

import SwiftUI

struct GuidedInstructionBar: View {
    let stepIndex: Int
    let totalSteps: Int
    let instructionText: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 3)
                }
            }

            Text(instructionText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 10)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: stepIndex)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            GuidedInstructionBar(stepIndex: 0, totalSteps: 2, instructionText: "Geser pelan ke semua dinding & plafon")
            Spacer()
        }
    }
}
