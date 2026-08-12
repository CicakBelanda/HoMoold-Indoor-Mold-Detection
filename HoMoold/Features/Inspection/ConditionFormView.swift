//
//  ConditionFormView.swift
//  HoMoold
//
//  Kondisi ruangan diisi MANUAL sama user (bukan hasil AI) — jamur/luas yang
//  AI deteksi cuma soal titik noda di CaptureView, sementara ini soal kondisi
//  umum ruangannya (ada AC/jendela, lembap, retak dinding) buat konteks
//  tambahan di Report. Kalau rumahnya belum punya lokasi sama sekali, lokasi
//  juga ditanya di sini (satu layar, sesuai Figma "Condition") — coba prefill
//  lewat GPS diam-diam pas layar muncul, user tetap bisa edit atau skip.
//

import SwiftUI

struct ConditionFormView: View {
    @ObservedObject var flow: InspectionFlowState
    @StateObject private var locationService = LocationService()

    private var showsLocationSection: Bool { flow.existingProperty.location.isEmpty }

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

            if showsLocationSection {
                Section {
                    TextField("Provinsi", text: $flow.location.region)
                    TextField("Kota/Kabupaten", text: $flow.location.city)
                    TextField("Kecamatan", text: $flow.location.district)
                } header: {
                    Text("Lokasi Rumah")
                } footer: {
                    if locationService.isFetching {
                        Label("Mengambil lokasi otomatis...", systemImage: "location.fill")
                            .foregroundStyle(.secondary)
                    } else if let error = locationService.errorMessage {
                        Text(error)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Opsional — boleh dilewati, bisa diisi belakangan.")
                    }
                }
            }
        }
        .navigationTitle("Kondisi Ruangan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            guard showsLocationSection else { return }
            if let found = await locationService.fetchCurrentLocation() {
                flow.location = found
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Lanjut") { proceed() }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(.bar)
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
    let property = KosProperty(name: "Kos Contoh", location: KosLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        ConditionFormView(flow: InspectionFlowState(existingProperty: property))
    }
}
