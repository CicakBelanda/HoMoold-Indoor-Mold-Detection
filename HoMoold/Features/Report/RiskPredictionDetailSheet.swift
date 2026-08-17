//
//  RiskPredictionDetailSheet.swift
//  HoMoold
//
//  Figma 1339:7649 ("Report Page 13") + 1339:7707 (state "See more" kebuka).
//
//  Halaman ini DI-PUSH (ada chevron back di desainnya), bukan sheet — dibuka
//  dari kartu "Mold Growth Risk Prediction" di Report.
//
//  Isinya: kartu prediksi, kartu Confidence Level (bar 3 segmen + balon nilai +
//  legenda + penjelasan yang bisa di-expand lewat "See more"), kartu Mold
//  Severity, dan kartu Total Mold Area.
//

import SwiftUI

struct RiskPredictionDetailSheet: View {
    @ObservedObject var viewModel: ReportViewModel
    @State private var isExplanationExpanded = false

    var body: some View {
        ZStack {
            Theme.color.surfaceMuted
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    predictionCard
                    confidenceCard
                    severityCard
                    areaCard
                    inputsCard
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(viewModel.inspection.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Kartu prediksi

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Label di sini 12pt (lebih kecil dari kartu di Report yang 17pt) —
            // sesuai desain, karena angkanya yang jadi fokus.
            Text("Mold Growth Rate Prediction")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textMuted)

            Text(viewModel.riskClass ?? "Unavailable")
                .font(Theme.font.statValue)
                .foregroundStyle(viewModel.riskClassColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(card)
    }

    // MARK: Kartu confidence

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Confidence Level")
                .font(Theme.font.title3)
                .foregroundStyle(Theme.color.textMuted)

            ConfidenceBar(
                fraction: viewModel.confidence,
                valueText: viewModel.confidenceText
            )

            legend

//            if !viewModel.confidenceBreakdown.isEmpty {
//                breakdown
//            }

            explanation
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(card)
    }

    private var legend: some View {
        VStack(spacing: 6) {
            legendRow(color: Theme.color.riskHigh, title: "Low Confidence Level", range: "40% or less")
            legendRow(color: Theme.color.confidenceMid, title: "Medium Confidence Level", range: "40% to 60%")
            legendRow(color: Theme.color.riskLow, title: "High Confidence Level", range: "60% or more")
        }
    }

    private func legendRow(color: Color, title: String, range: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textPrimary)

            Text(range)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textMuted)

            Spacer(minLength: 0)
        }
    }

    /// Sebaran peluang tiap level.
    ///
    /// Ini yang bikin angka di atas masuk akal: "93,94%" itu porsi level yang
    /// menang, BUKAN akumulasi semua level. Totalnya selalu 100%. Kalau
    /// angkanya sering sama persis buat ruangan yang beda, itu wajar — model
    /// pohon keputusan ngasih peluang yang sama buat semua input yang jatuh di
    /// daun yang sama.
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How the model split its confidence")
                .font(Theme.font.footnote)
                .foregroundStyle(Theme.color.textMuted)

            ForEach(viewModel.confidenceBreakdown, id: \.label) { entry in
                HStack(spacing: 10) {
                    Text(entry.label)
                        .font(Theme.font.subheadline)
                        .foregroundStyle(Theme.color.textPrimary)
                        .frame(width: 68, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.color.textSecondary.opacity(0.15))
                            Capsule()
                                .fill(color(for: entry.label))
                                .frame(width: geo.size.width * entry.value)
                        }
                    }
                    .frame(height: 6)

                    Text(percentText(entry.value))
                        .font(Theme.font.footnote)
                        .foregroundStyle(Theme.color.textMuted)
                        .frame(width: 54, alignment: .trailing)
                }
            }
        }
    }

    private func color(for label: String) -> Color {
        switch label.lowercased() {
        case "low": return Theme.color.riskLow
        case "medium": return Theme.color.riskMedium
        default: return Theme.color.riskHigh
        }
    }

    private func percentText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        return "\(formatter.string(from: NSNumber(value: value * 100)) ?? "—")%"
    }

    /// Penjelasan singkat + "See more". Di Figma link-nya biru (`#08f`), tapi
    /// warna itu sengaja diganti brand teal — biru Apple nggak dipakai di app
    /// ini.
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isExplanationExpanded ? Self.explanationFull : Self.explanationShort)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if !isExplanationExpanded {
                Button("See more") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExplanationExpanded = true
                    }
                }
                .font(Theme.font.body)
            }
        }
    }

    private static let explanationShort =
        "Every mold growth risk score comes with a confidence level, which tells how much certainty hoomold has in the result."

    private static let explanationFull =
        """
        Every mold growth risk score comes with a confidence level, which tells how much certainty hoomold has in the result. Confidence is based on how much information was available clearer photos, more visible detail, and more reported conditions (like humidity, ventilation, etc) all lead to higher confidence. When something is hard to detect, like poor lighting or missing details about your room, your confidence level will be lower, even if the risk or severity score itself stays the same.
        """

    // MARK: Kartu ringkas

    private var severityCard: some View {
        statCard(
            title: "Mold Severity",
            value: viewModel.moldSeverityText,
            iconBackground: Theme.color.iconSeverityBackground
        ) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.color.confidenceMid)
        }
    }

    private var areaCard: some View {
        statCard(
            title: "Total Mold Area",
            value: viewModel.totalAreaText ?? "Not measured",
            note: viewModel.areaCoverageNote,
            iconBackground: Theme.color.iconAreaBackground
        ) {
            Image(systemName: "square.dashed")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.color.textSecondary)
        }
    }

    /// Daftar input mentah yang masuk ke model.
    ///
    /// Ini bukan hiasan: tanpa ini, "kenapa selalu High" nggak bisa dijawab dari
    /// dalam app. Dengan angkanya kelihatan, langsung ketahuan kalau misalnya
    /// kelembapannya kebaca 90% padahal ruangannya ber-AC dan kering.
    @ViewBuilder
    private var inputsCard: some View {
        let inputs = viewModel.modelInputs

        if inputs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prediction inputs")
                    .font(Theme.font.title3)
                    .foregroundStyle(Theme.color.textMuted)

                Text("The weather couldn't be read for this room, so no prediction was made.")
                    .font(Theme.font.subheadline)
                    .foregroundStyle(Theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(card)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prediction inputs")
                    .font(Theme.font.title3)
                    .foregroundStyle(Theme.color.textMuted)

                VStack(spacing: 0) {
                    ForEach(Array(inputs.enumerated()), id: \.element.label) { index, row in
                        if index > 0 { Divider() }
                        HStack {
                            Text(row.label)
                                .font(Theme.font.subheadline)
                                .foregroundStyle(Theme.color.textPrimary)
                            Spacer(minLength: 8)
                            Text(row.value)
                                .font(Theme.font.subheadline)
                                .foregroundStyle(Theme.color.textMuted)
                        }
                        .frame(height: 34)
                    }
                }

                Text("Humidity comes from the outdoor weather at your location, not from inside the room.")
                    .font(Theme.font.footnote)
                    .foregroundStyle(Theme.color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(card)
        }
    }

    private func statCard<Icon: View>(
        title: String,
        value: String,
        note: String? = nil,
        iconBackground: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            icon()
                .frame(width: 49, height: 49)
                .background(
                    iconBackground,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textMuted)

                Text(value)
                    .font(Theme.font.title3Emphasized)
                    .foregroundStyle(Theme.color.textPrimary)

                if let note {
                    Text(note)
                        .font(Theme.font.footnote)
                        .foregroundStyle(Theme.color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.color.card)
    }
}

// MARK: - Confidence bar

/// Bar 3 segmen (merah / kuning / hijau) dengan balon nilai di atasnya.
///
/// Lebar segmennya ngikutin ambang batas legendanya — 40% / 20% / 40% — jadi
/// posisi balonnya beneran nunjuk ke zona yang bener, bukan sekadar mirip
/// gambar di Figma.
private struct ConfidenceBar: View {
    /// 0–1. `nil` = prediksi nggak tersedia.
    let fraction: Double?
    let valueText: String?

    private let lowUpperBound = 0.4
    private let midUpperBound = 0.6

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let clamped = min(max(fraction ?? 0, 0), 1)

                ZStack(alignment: .topLeading) {
                    // Segmen bar, ditaruh di bawah balon.
                    HStack(spacing: 4) {
                        Capsule().fill(Theme.color.riskHigh)
                            .frame(width: (width - 8) * lowUpperBound)
                        Capsule().fill(Theme.color.confidenceMid)
                            .frame(width: (width - 8) * (midUpperBound - lowUpperBound))
                        Capsule().fill(Theme.color.riskLow)
                    }
                    .frame(height: 6)
                    .offset(y: 34)

                    if let valueText {
                        tooltip(valueText)
                            // Dijaga biar balonnya nggak kepotong di ujung.
                            .offset(x: min(max(width * clamped - 37, 0), width - 75))
                    }
                }
            }
            .frame(height: 40)

            HStack {
                Text("0%")
                Spacer()
                Text("100%")
            }
            .font(Theme.font.caption)
            .foregroundStyle(Theme.color.textPrimary)
        }
    }

    private func tooltip(_ text: String) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(Theme.font.callout)
                .foregroundStyle(.white)
                .frame(width: 75, height: 23)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.color.tooltip)
                )

            Triangle()
                .fill(Theme.color.tooltip)
                .frame(width: 12, height: 7)
        }
    }
}

/// Segitiga kecil penunjuk di bawah balon nilai.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
