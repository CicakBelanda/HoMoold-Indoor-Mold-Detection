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

    /// Izin lokasi ditolak/dibatasi secara eksplisit — beda dari "gagal ambil
    /// lokasi". Dibedain karena penanganannya beda: iOS nggak akan nanya izin
    /// dua kali, jadi satu-satunya jalan balik itu lewat Settings, dan UI perlu
    /// tau bedanya biar bisa nawarin tombol itu (lihat ConditionFormView).
    @Published var isPermissionDenied = false

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
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

        guard isAuthorized else {
            markPermissionDenied("Location access hasn't been granted, so the weather can't be fetched automatically.")
            return nil
        }
        isPermissionDenied = false

        do {
            let location = try await requestLocation()
            return location.coordinate
        } catch {
            errorMessage = "Can't get your location right now, so the weather can't be fetched automatically."
            return nil
        }
    }

    /// Ubah koordinat jadi nama wilayah (provinsi/kota/kecamatan).
    ///
    /// Dipisah dari pengambilan koordinat supaya pemanggilnya bisa MINTA GPS
    /// SEKALI lalu memakai koordinat yang sama buat cuaca DAN nama lokasi —
    /// dua permintaan GPS berturut-turut bikin form-nya nunggu dua kali.
    func placemark(for coordinate: CLLocationCoordinate2D) async -> HomeLocation? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        // `thoroughfare` = nama jalan, `subThoroughfare` = nomor rumah.
        // Digabung jadi satu baris alamat kalau dua-duanya ada.
        let street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " No. ")

        let district = placemark.subLocality ?? placemark.subAdministrativeArea ?? ""
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        let region = placemark.administrativeArea ?? ""
        guard !street.isEmpty || !district.isEmpty || !city.isEmpty || !region.isEmpty else {
            return nil
        }
        let districtText = district.isEmpty || district.hasPrefix("Kec.") ? district : "Kec. \(district)"
        return HomeLocation(street: street, region: region, city: city, district: districtText)
    }

    private var isAuthorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    private func markPermissionDenied(_ message: String) {
        // `.notDetermined` di titik ini berarti user nutup dialog tanpa milih —
        // bukan penolakan permanen, jadi jangan tawarin Settings.
        isPermissionDenied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        errorMessage = message
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
