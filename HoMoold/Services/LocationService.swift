//
//  LocationService.swift
//  HoMoold
//
//  Ambil lokasi (kecamatan) otomatis pas nambah kos baru, biar user gak perlu
//  ngetik manual. Kalau ditolak/gagal, tetap bisa isi manual.
//

import Combine
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var isFetching = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Kembalikan nama kecamatan/lokasi dari posisi user saat ini, atau nil kalau gagal.
    func fetchCurrentLocationName() async -> String? {
        isFetching = true
        errorMessage = nil
        defer { isFetching = false }

        if manager.authorizationStatus == .notDetermined {
            await requestAuthorization()
        }

        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            errorMessage = "Akses lokasi belum diizinkan. Isi manual, ya."
            return nil
        }

        do {
            let location = try await requestLocation()
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            let name = placemark.subLocality ?? placemark.locality ?? placemark.administrativeArea
            guard let name else {
                errorMessage = "Nama lokasi tidak ditemukan. Isi manual, ya."
                return nil
            }
            return name.hasPrefix("Kec.") ? name : "Kec. \(name)"
        } catch {
            errorMessage = "Tidak bisa ambil lokasi sekarang. Isi manual, ya."
            return nil
        }
    }

    private func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authContinuation?.resume()
            self.authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }
}
