//
//  LocationService.swift
//  HoMoold
//
//  Ambil lokasi (region/kota/kecamatan) otomatis pas nambah rumah baru, buat
//  nge-prefill ConditionFormView — user tetap bisa edit/isi manual kalau GPS
//  gagal atau salah.
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

    /// Kembalikan region/kota/kecamatan dari posisi user saat ini, atau nil kalau gagal
    /// (izin ditolak, GPS gagal, dst.) — caller-nya (ConditionFormView) tetap bisa
    /// lanjut isi manual.
    func fetchCurrentLocation() async -> HomeLocation? {
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
            guard let placemark = placemarks.first else {
                errorMessage = "Lokasi tidak ditemukan. Isi manual, ya."
                return nil
            }
            let district = placemark.subLocality ?? placemark.subAdministrativeArea ?? ""
            let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
            let region = placemark.administrativeArea ?? ""
            guard !district.isEmpty || !city.isEmpty || !region.isEmpty else {
                errorMessage = "Nama lokasi tidak ditemukan. Isi manual, ya."
                return nil
            }
            let districtText = district.isEmpty || district.hasPrefix("Kec.") ? district : "Kec. \(district)"
            return HomeLocation(region: region, city: city, district: districtText)
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

    /// Kembalikan koordinat (lat/lon) user saat ini, atau nil kalau gagal /
    /// izin ditolak. Dipakai buat ambil cuaca lewat WeatherService (bukan
    /// reverse-geocode nama lokasi).
    func fetchCurrentCoordinate() async -> CLLocationCoordinate2D? {
        isFetching = true
        errorMessage = nil
        defer { isFetching = false }

        if manager.authorizationStatus == .notDetermined {
            await requestAuthorization()
        }

        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            errorMessage = "Akses lokasi belum diizinkan. Cuaca gak bisa diambil otomatis."
            return nil
        }

        do {
            let location = try await requestLocation()
            return location.coordinate
        } catch {
            errorMessage = "Tidak bisa ambil lokasi sekarang. Cuaca gak bisa diambil otomatis."
            return nil
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
