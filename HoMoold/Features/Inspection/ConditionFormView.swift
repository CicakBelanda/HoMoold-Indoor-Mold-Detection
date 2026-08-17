//
//  ConditionFormView.swift
//  HoMoold
//
//  Kondisi ruangan diisi MANUAL sama user (bukan hasil AI) — jamur/luas yang
//  AI deteksi cuma soal titik noda di CaptureView, sementara ini soal kondisi
//  umum ruangannya (ada AC/jendela, lembap, retak dinding) buat konteks
//  tambahan di Report.
//
//  Bagian "Kondisi Cuaca" menggantikan input lokasi (provinsi/kabupaten/
//  kecamatan) — sekarang cuaca di tempat user diambil OTOMATIS lewat
//  LocationService (koordinat) + WeatherService (Open-Meteo: suhu & kelembapan),
//  gak perlu diketik manual. UI-nya tetap Form/Section sama kayak sebelumnya:
//  header + footer yang nunjukin status mengambil/error/opsional.

import SwiftUI
import CoreLocation

struct ConditionFormView: View {
    @ObservedObject var flow: InspectionFlowState
    @StateObject private var locationService = LocationService()
    private let weatherService = WeatherService()

    var body: some View {
        Form {
            Section {
                Toggle("Damp", isOn: $flow.dampness)
                Toggle("Wall Crack", isOn: $flow.wallCrack)
                Toggle("AC", isOn: $flow.hasAC)
                Toggle("Window", isOn: $flow.hasWindow)
            } header: {
                Text("Room Condition")
            } footer: {
                Text("Fill in according to what you see directly in this room.")
            }

            Section {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(weatherText(flow.temperature, unit: "°C"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Humidity")
                    Spacer()
                    Text(weatherText(flow.humidity, unit: "%"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Weather Condition")
            } footer: {
                if locationService.isFetching {
                    Label("Fetching weather automatically...", systemImage: "location.fill")
                        .foregroundStyle(.secondary)
                } else if let error = locationService.errorMessage {
                    Text(error)
                        .foregroundStyle(.orange)
                } else if flow.temperature == nil && flow.humidity == nil {
                    Text("Weather couldn't be fetched. Just continue, it's fine.")
                } else {
                    Text("Automatically retrieved from your current location.")
                }
            }
        }
        .navigationTitle("Room Condition")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await refreshWeather()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Next") { proceed() }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(.bar)
        }
    }

    private func weatherText(_ value: Float?, unit: String) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f %@", value, unit)
    }

    private func refreshWeather() async {
        guard let coord = await locationService.fetchCurrentCoordinate() else { return }
        do {
            let snap = try await weatherService.fetchCurrent(lat: coord.latitude, lon: coord.longitude)
            flow.temperature = snap.temperature
            flow.humidity = snap.humidity
        } catch {
            locationService.errorMessage = "Weather couldn't be fetched: \(error.localizedDescription)"
        }
    }

    private func proceed() {
        let score = min(95, flow.capturedFindings.count * 12)
        // Level keparahan (0–3) dari total luas jamur — input `Mold` model.
        let totalArea = flow.capturedFindings.compactMap(\.areaCM2).reduce(0, +)
        let moldLevel = totalArea > 0 ? MoldSeverity.severity(fromAreaCM2: totalArea).level : 0
        flow.resultInspection = RoomInspection(
            roomType: flow.roomType ?? .bedroom,
            riskLevel: RiskLevel.level(forScore: score),
            riskScore: score,
            findings: flow.capturedFindings,
            capturedPhotos: flow.capturedPhotos,
            hasAC: flow.hasAC,
            hasWindow: flow.hasWindow,
            dampness: flow.dampness,
            wallCrack: flow.wallCrack,
            date: Date(),
            temperature: flow.temperature,
            humidity: flow.humidity,
            moldSeverityLevel: moldLevel
        )
        flow.path.append(.report)
    }
}

#Preview {
    let property = KosProperty(name: "Sample Property", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        ConditionFormView(flow: InspectionFlowState(existingProperty: property))
    }
}
