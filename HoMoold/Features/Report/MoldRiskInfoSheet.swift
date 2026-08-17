//
//  MoldRiskInfoSheet.swift
//  HoMoold
//
//  Figma 1339:6670 / 1339:6742 ("Summary") — kebuka dari menu Report.
//
//  "See more" DI SINI bukan buat manjangin paragraf, tapi buat mbuka RINCIAN
//  PER LEVEL-nya: "How Risk Levels Work" -> Low / Medium / High Rate,
//  "How Severity Levels Work" -> No Mold / Low / Moderate / Severe.
//
//  Level-levelnya dikasih titik berwarna + kartu sendiri, bukan ditumpuk jadi
//  deretan judul tebal kayak versi sebelumnya. Alasannya: kalau semuanya
//  berbentuk judul + paragraf dengan berat yang sama, mata nggak bisa mbedain
//  mana "topik" dan mana "salah satu level di dalam topik itu" — dan
//  sheet-nya kebaca sebagai satu dinding teks panjang.
//

import SwiftUI

struct MoldRiskInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(InfoSection.all) { section in
                        sectionCard(section)
                    }
                }
                .padding(16)
            }
            .background(Theme.color.surfaceMuted.ignoresSafeArea())
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tint(.primary)
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    /// Tiap topik jadi KARTU sendiri. Ini pemisah utamanya: batas kartu yang
    /// bikin jelas di mana satu topik selesai dan topik berikutnya mulai.
    private func sectionCard(_ section: InfoSection) -> some View {
        let isExpanded = expandedSections.contains(section.id)

        return VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(Theme.font.title3Emphasized)
                .foregroundStyle(Theme.color.textPrimary)

            Text(section.body)
                .font(Theme.font.subheadline)
                .foregroundStyle(Theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !section.levels.isEmpty {
                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(section.levels) { level in
                            levelRow(level)
                        }
                    }
                    .padding(.top, 2)
                }

                Button(isExpanded ? "Show less" : "See more") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        if isExpanded {
                            expandedSections.remove(section.id)
                        } else {
                            expandedSections.insert(section.id)
                        }
                    }
                }
                .font(Theme.font.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            Theme.color.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    /// Satu level: titik warna + nama + penjelasan, di atas surface yang lebih
    /// redup. Warnanya yang bikin level kebaca sekilas tanpa harus dibaca
    /// hurufnya.
    private func levelRow(_ level: InfoSection.Level) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(level.color)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(level.title)
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)

                Text(level.body)
                    .font(Theme.font.subheadline)
                    .foregroundStyle(Theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            Theme.color.surfaceMuted,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Content

/// Copy dari Figma 1339:6670 / 1339:6742.
private struct InfoSection: Identifiable {
    var id: String { title }
    var title: String
    var body: String
    /// Rincian per level yang kebuka lewat "See more". Kosong = nggak ada
    /// tombolnya sama sekali.
    var levels: [Level] = []

    struct Level: Identifiable {
        var id: String { title }
        var title: String
        var body: String
        var color: Color
    }

    static let all: [InfoSection] = [
        InfoSection(
            title: "How Your Score is Calculated",
            body: """
            hoomold gives two scores. Mold Growth Risk reflects conditions like dampness, humidity, temperature, \
            ventilation, and cracks that make mold more likely over time. Mold Severity measures how much visible mold \
            currently covers your space.
            """
        ),
        InfoSection(
            title: "How Risk Levels Work",
            body: """
            Your environment is classified into risk levels based on conditions that support mold growth. A higher risk \
            means your space has more factors that allow mold to develop over time.
            """,
            levels: [
                Level(
                    title: "Low Rate",
                    body: """
                    Your environment shows few conditions that support mold growth. Continue maintaining good \
                    ventilation and controlling moisture to help keep the risk low.
                    """,
                    color: Theme.color.riskLow
                ),
                Level(
                    title: "Medium Rate",
                    body: """
                    Your environment has some conditions that may encourage mold growth over time. Improving airflow, \
                    reducing humidity, and addressing moisture sources can help lower the risk.
                    """,
                    color: Theme.color.riskMedium
                ),
                Level(
                    title: "High Rate",
                    body: """
                    Your environment shows multiple conditions that strongly support mold growth. Taking action soon to \
                    improve ventilation and resolve moisture issues may help prevent mold from developing or spreading.
                    """,
                    color: Theme.color.riskHigh
                ),
            ]
        ),
        InfoSection(
            title: "How Severity Levels Work",
            body: """
            hoomold can analyze and classify visible mold into four severity levels. They reflect the current extent of \
            mold coverage, which may differ from your overall risk of future growth.
            """,
            levels: [
                Level(
                    title: "No Mold Severity",
                    body: """
                    No visible mold was found in your space. This doesn't rule out risk from moisture or humidity, but \
                    there's currently nothing to clean or treat.
                    """,
                    color: Theme.color.textSecondary
                ),
                Level(
                    title: "Low Severity",
                    body: """
                    Mold coverage is minimal, under 600 cm². This is often an early sign, and small patches can usually \
                    be handled with simple cleaning.
                    """,
                    color: Theme.color.riskLow
                ),
                Level(
                    title: "Moderate Severity",
                    body: """
                    Mold has spread across a noticeable area, between 600 cm² and 16.400 cm². At this stage it is worth \
                    treating the surface and fixing whatever is keeping it damp.
                    """,
                    color: Theme.color.riskMedium
                ),
                Level(
                    title: "Severe Severity",
                    body: """
                    Mold covers more than 16.400 cm². Coverage this wide usually points to an ongoing moisture problem, and \
                    is worth getting looked at properly rather than cleaned over.
                    """,
                    color: Theme.color.riskHigh
                ),
            ]
        ),
        InfoSection(
            title: "The Formula Behind the Curtains",
            body: """
            Our mold growth model draws on peer-reviewed building science, including "Modelling mould growth in domestic \
            environments using relative humidity and temperature" (Menneer, Mueller, Sharpe & Townley, Building and \
            Environment, 2022). That research links sustained humidity and temperature to how likely mould is to \
            establish indoors, which is why hoomold asks about your room and reads the local weather instead of judging \
            from photos alone.
            """
        ),
    ]
}

#Preview {
    MoldRiskInfoSheet()
}
