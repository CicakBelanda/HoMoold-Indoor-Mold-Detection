//
//  WeatherService.swift
//  HoMoold
//
//  Fetches the current temperature and relative humidity from Open-Meteo
//  (https://api.open-meteo.com) for a given latitude/longitude. No API key
//  is required. Returns a WeatherSnapshot the View can display in
//  ConditionFormView.
//

import Foundation

struct WeatherSnapshot {
    let temperature: Float   // °C
    let humidity: Float       // %
}

enum WeatherServiceError: LocalizedError {
    case badURL
    case decodingFailed
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid weather request URL."
        case .decodingFailed:
            return "Could not read the weather data."
        case .requestFailed(let e):
            return "Weather request failed: \(e.localizedDescription)"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
    }
    let current: Current
}

@MainActor
final class WeatherService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCurrent(lat: Double, lon: Double) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m")
        ]

        guard let url = components?.url else { throw WeatherServiceError.badURL }

        do {
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return WeatherSnapshot(
                temperature: Float(decoded.current.temperature_2m),
                humidity: Float(decoded.current.relative_humidity_2m)
            )
        } catch let e as WeatherServiceError {
            throw e
        } catch {
            throw WeatherServiceError.requestFailed(error)
        }
    }
}
