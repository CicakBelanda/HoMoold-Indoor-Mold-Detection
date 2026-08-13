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
                Toggle("Lembap", isOn: $flow.dampness)
                Toggle("Retak Dinding", isOn: $flow.wallCrack)
                Toggle("AC", isOn: $flow.hasAC)
                Toggle("Jendela", isOn: $flow.hasWindow)
            } header: {
                Text("Kondisi Ruangan")
            } footer: {
                Text("Isi sesuai yang kamu lihat langsung di ruangan ini.")
            }

            Section {
                HStack {
                    Text("Suhu")
                    Spacer()
                    Text(weatherText(flow.temperature, unit: "°C"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Kelembapan")
                    Spacer()
                    Text(weatherText(flow.humidity, unit: "%"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Kondisi Cuaca")
            } footer: {
                if locationService.isFetching {
                    Label("Mengambil cuaca otomatis...", systemImage: "location.fill")
                        .foregroundStyle(.secondary)
                } else if let error = locationService.errorMessage {
                    Text(error)
                        .foregroundStyle(.orange)
                } else if flow.temperature == nil && flow.humidity == nil {
                    Text("Cuaca gak bisa diambil. Lanjut aja, nggak masalah.")
                } else {
                    Text("Diambil otomatis dari lokasimu saat ini.")
                }
            }
        }
        .navigationTitle("Kondisi Ruangan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await refreshWeather()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Lanjut") { proceed() }
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
            locationService.errorMessage = "Cuaca gak bisa diambil: \(error.localizedDescription)"
        }
    }

    private func proceed() {
        let score = min(95, flow.capturedFindings.count * 12)
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
            date: Date()
        )
        flow.path.append(.report)
    }
}

#Preview {
    let property = KosProperty(name: "Kos Contoh", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        ConditionFormView(flow: InspectionFlowState(existingProperty: property))
    }
}
