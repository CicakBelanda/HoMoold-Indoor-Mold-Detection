//
//  GuidedInstructionBar.swift
//  HoMoold
//
//  Bar instruksi live di atas layar rekam — ganti step otomatis berdasar hasil
//  deteksi asli (bukan timer tetap), plus tombol Lewati buat kamar yang gak
//  punya AC/jendela. Jumlah titik progress ngikutin jumlah step yang relevan
//  buat tipe ruangan ini (lihat GuidedRecordingController).
//

import SwiftUI

struct GuidedInstructionBar: View {
    let stepIndex: Int
    let totalSteps: Int
    let instructionText: String
    let canSkip: Bool
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 3)
                }
            }

            HStack(spacing: 10) {
                Text(instructionText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if canSkip {
                    Button("Lewati", action: onSkip)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.25), in: Capsule())
                }
            }
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
            GuidedInstructionBar(stepIndex: 0, totalSteps: 4, instructionText: "Arahkan kamera ke AC dulu, kalau kamar ini ada AC-nya", canSkip: true, onSkip: {})
            Spacer()
        }
    }
}
