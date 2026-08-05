//
//  RecordingGuideOverlay.swift
//  HoMoold
//
//  Overlay panduan gaya "story": progress bar tersegmen + tombol prev/next yang
//  kelihatan, bukan cuma auto-advance berbasis timer. User bisa maju-mundur
//  sendiri kalau captionnya kecepetan/kelambatan, tapi tetap auto-jalan sebagai
//  fallback biar tangan bisa fokus megang HP & merekam.
//

import Combine
import SwiftUI

struct RecordingGuideOverlay: View {
    let steps: [String]
    let isActive: Bool
    var stepDuration: TimeInterval = 6

    @State private var currentIndex = 0
    @State private var elapsedInStep: TimeInterval = 0
    private let tickInterval: TimeInterval = 0.05
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(steps.indices, id: \.self) { index in
                    SegmentBar(fill: fillAmount(for: index))
                }
            }

            HStack(spacing: 12) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(currentIndex == 0 ? 0.3 : 0.95))
                }
                .disabled(currentIndex == 0)
                .accessibilityLabel("Panduan sebelumnya")

                Text(steps[safe: currentIndex] ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .id(currentIndex)
                    .transition(.opacity)

                Button {
                    goNext()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(currentIndex == steps.count - 1 ? 0.3 : 0.95))
                }
                .disabled(currentIndex == steps.count - 1)
                .accessibilityLabel("Panduan selanjutnya")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 10)
        .padding(.horizontal, 16)
        .onReceive(timer) { _ in
            guard isActive else { return }
            elapsedInStep += tickInterval
            if elapsedInStep >= stepDuration {
                goNext(auto: true)
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                currentIndex = 0
                elapsedInStep = 0
            }
        }
    }

    private func fillAmount(for index: Int) -> CGFloat {
        if index < currentIndex { return 1 }
        if index > currentIndex { return 0 }
        return CGFloat(elapsedInStep / stepDuration)
    }

    private func goNext(auto: Bool = false) {
        guard currentIndex < steps.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
            elapsedInStep = 0
        }
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex -= 1
            elapsedInStep = 0
        }
    }
}

private struct SegmentBar: View {
    let fill: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.35))
                Capsule().fill(Color.white).frame(width: geo.size.width * max(0, min(1, fill)))
            }
        }
        .frame(height: 3)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        Color.black
        RecordingGuideOverlay(
            steps: [
                "Mulai dari jendela atau ventilasi kamar ini",
                "Ada AC? Arahkan ke situ sebentar",
            ],
            isActive: true
        )
    }
}
