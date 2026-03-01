// Packages/WeatherFun/Sources/WeatherFun/WeatherViewModel.swift
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: - Scene State (not @Published — read by SpriteKit scene directly)
    var weatherType: WeatherType = .sunny
    var intensity: CGFloat = 0.0
    var isTouching: Bool = false

    // MARK: - Published State (only for SwiftUI settings sheet)
    @Published var zipCode: String {
        didSet { UserDefaults.standard.set(zipCode, forKey: "weatherZipCode") }
    }
    @Published var zipError: String? = nil

    // MARK: - Private
    private var displayLink: CADisplayLink?
    private var refreshTimer: Timer?
    private var cachedWeather: WeatherType?
    private let geocoder = CLGeocoder()

    // MARK: - Init
    init() {
        self.zipCode = UserDefaults.standard.string(forKey: "weatherZipCode") ?? "43123"
    }

    // MARK: - Lifecycle

    func onAppear() {
        startDisplayLink()
        fetchWeather()
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchWeather()
            }
        }
    }

    func onDisappear() {
        displayLink?.invalidate()
        displayLink = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Intensity Update (called every frame)

    private func startDisplayLink() {
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            self?.updateIntensity()
        }, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func updateIntensity() {
        if isTouching {
            intensity = min(1.0, intensity + IntensityConfig.rampRate)
        } else if intensity > 0 {
            intensity = max(0.0, intensity - IntensityConfig.decayRate)
        }
    }

    // MARK: - Weather Fetch

    func fetchWeather() {
        let zip = zipCode
        guard zip.count == 5, zip.allSatisfy({ $0.isNumber }) else {
            zipError = "Enter a 5-digit zip code"
            return
        }
        zipError = nil

        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(zip) { [weak self] placemarks, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let location = placemarks?.first?.location else {
                    self.weatherType = self.cachedWeather ?? self.randomWeather()
                    return
                }
                self.fetchFromOpenMeteo(location: location)
            }
        }
    }

    // MARK: - Open-Meteo API (free, no key required)

    private func fetchFromOpenMeteo(location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=weather_code&timezone=auto"

        guard let url = URL(string: urlString) else {
            self.weatherType = cachedWeather ?? randomWeather()
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let weather = mapWeatherCode(response.current.weatherCode)
                self.weatherType = weather
                self.cachedWeather = weather
            } catch {
                self.weatherType = self.cachedWeather ?? self.randomWeather()
            }
        }
    }

    /// Maps WMO weather codes to our WeatherType
    /// See: https://open-meteo.com/en/docs#weathervariables
    private func mapWeatherCode(_ code: Int) -> WeatherType {
        switch code {
        case 0, 1:
            // Clear sky, mainly clear
            return .sunny
        case 2, 3, 45, 48:
            // Partly cloudy, overcast, fog, depositing rime fog
            return .cloudy
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            // Drizzle, rain, freezing rain, rain showers, thunderstorm
            return .rainy
        case 71, 73, 75, 77, 85, 86:
            // Snow fall, snow grains, snow showers
            return .snowy
        default:
            return .cloudy
        }
    }

    private func randomWeather() -> WeatherType {
        // Deterministic per day so it doesn't jump around
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let types = WeatherType.allCases
        return types[day % types.count]
    }
}

// MARK: - Display Link Helper (avoids @objc on WeatherViewModel)

private class DisplayLinkTarget {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func tick() { callback() }
}

// MARK: - Open-Meteo JSON Response

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable {
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case weatherCode = "weather_code"
        }
    }
}
