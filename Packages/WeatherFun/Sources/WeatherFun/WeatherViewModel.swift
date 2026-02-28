// Packages/WeatherFun/Sources/WeatherFun/WeatherViewModel.swift
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: - Published State
    @Published var weatherType: WeatherType = .sunny
    @Published var intensity: CGFloat = 0.0
    @Published var isTouching: Bool = false
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
        self.zipCode = UserDefaults.standard.string(forKey: "weatherZipCode") ?? "10001"
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
                self.fetchFromWeatherKit(location: location)
            }
        }
    }

    private func fetchFromWeatherKit(location: CLLocation) {
        #if canImport(WeatherKit)
        if #available(iOS 16, *) {
            Task {
                do {
                    let weather = try await WeatherServiceBridge.fetchCurrent(location: location)
                    self.weatherType = weather
                    self.cachedWeather = weather
                } catch {
                    self.weatherType = self.cachedWeather ?? self.randomWeather()
                }
            }
        } else {
            self.weatherType = randomWeather()
        }
        #else
        self.weatherType = cachedWeather ?? randomWeather()
        #endif
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

// MARK: - WeatherKit Bridge (iOS 16+)

#if canImport(WeatherKit)
import WeatherKit

enum WeatherServiceBridge {
    @available(iOS 16, *)
    static func fetchCurrent(location: CLLocation) async throws -> WeatherType {
        let service = WeatherService.shared
        let weather = try await service.weather(for: location, including: .current)
        return mapCondition(weather.condition)
    }

    @available(iOS 16, *)
    private static func mapCondition(_ condition: WeatherCondition) -> WeatherType {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .sunny
        case .rain, .heavyRain, .drizzle, .thunderstorms, .tropicalStorm:
            return .rainy
        case .snow, .heavySnow, .sleet, .freezingRain, .freezingDrizzle, .blizzard, .flurries:
            return .snowy
        default:
            return .cloudy
        }
    }
}
#endif
