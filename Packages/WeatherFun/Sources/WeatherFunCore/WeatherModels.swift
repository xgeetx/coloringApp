// Packages/WeatherFun/Sources/WeatherFunCore/WeatherModels.swift
// Pure logic — no UIKit/SpriteKit, testable on macOS
import Foundation
import CoreGraphics

// MARK: - Weather Type

public enum WeatherType: String, CaseIterable {
    case sunny, cloudy, rainy, snowy
}

// MARK: - Intensity Thresholds

public enum IntensityThreshold {
    public static let groundEffects: CGFloat  = 0.3
    public static let soundRamp: CGFloat      = 0.5
    public static let characterTrigger: CGFloat = 0.6
    public static let peakEffects: CGFloat    = 0.8
}

// MARK: - Intensity Config

public struct IntensityConfig {
    /// Per-frame increment while touching (~60fps → 0→1 in ~13s)
    public static let rampRate: CGFloat   = 0.005
    /// Per-frame decrement while not touching (1→0 in ~33s)
    public static let decayRate: CGFloat  = 0.002
}

// MARK: - Sky Colors Per Weather Type

public struct SkyConfig {
    public let topColor: (r: Int, g: Int, b: Int)
    public let bottomColor: (r: Int, g: Int, b: Int)
    /// How much the scene darkens/warms at max intensity (0–1)
    public let intenseTintAlpha: CGFloat
    public let intenseTintColor: (r: Int, g: Int, b: Int)

    public static let sunny = SkyConfig(
        topColor: (70, 130, 220),
        bottomColor: (160, 210, 255),
        intenseTintAlpha: 0.3,
        intenseTintColor: (255, 200, 50)  // golden warm
    )
    public static let cloudy = SkyConfig(
        topColor: (140, 155, 175),
        bottomColor: (190, 200, 210),
        intenseTintAlpha: 0.4,
        intenseTintColor: (80, 80, 90)  // dark gray
    )
    public static let rainy = SkyConfig(
        topColor: (80, 95, 120),
        bottomColor: (130, 145, 165),
        intenseTintAlpha: 0.35,
        intenseTintColor: (40, 50, 70)  // dark blue-gray
    )
    public static let snowy = SkyConfig(
        topColor: (180, 195, 210),
        bottomColor: (220, 225, 235),
        intenseTintAlpha: 0.25,
        intenseTintColor: (240, 240, 250)  // white-blue
    )

    public static func config(for type: WeatherType) -> SkyConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}

// MARK: - Audio Config

public struct AudioConfig {
    public let ambientFile: String      // filename without extension
    public let ambientExtension: String // "m4a"
    public let minVolume: Float
    public let maxVolume: Float
    public let characterSoundFile: String?
    public let characterSoundExtension: String?

    public static let sunny = AudioConfig(
        ambientFile: "ambient_sunny", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.7,
        characterSoundFile: "sfx_giggle", characterSoundExtension: "caf"
    )
    public static let cloudy = AudioConfig(
        ambientFile: "ambient_cloudy", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.5,
        characterSoundFile: "sfx_wind_gust", characterSoundExtension: "caf"
    )
    public static let rainy = AudioConfig(
        ambientFile: "ambient_rainy", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.8,
        characterSoundFile: "sfx_splash", characterSoundExtension: "caf"
    )
    public static let snowy = AudioConfig(
        ambientFile: "ambient_snowy", ambientExtension: "m4a",
        minVolume: 0.05, maxVolume: 0.4,
        characterSoundFile: "sfx_snow_crunch", characterSoundExtension: "caf"
    )

    public static func config(for type: WeatherType) -> AudioConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}

// MARK: - Character Config

public struct CharacterConfig {
    public let spriteSheet: String    // image name in bundle
    public let frameCount: Int
    public let timePerFrame: TimeInterval
    public let crossDuration: TimeInterval
    public let cooldown: TimeInterval

    public static let sunny = CharacterConfig(
        spriteSheet: "character_sunny_sheet",
        frameCount: 4, timePerFrame: 0.15,
        crossDuration: 3.0, cooldown: 10.0
    )
    public static let cloudy = CharacterConfig(
        spriteSheet: "character_cloudy_sheet",
        frameCount: 4, timePerFrame: 0.25,
        crossDuration: 4.0, cooldown: 10.0
    )
    public static let rainy = CharacterConfig(
        spriteSheet: "character_rainy_sheet",
        frameCount: 4, timePerFrame: 0.12,
        crossDuration: 3.0, cooldown: 10.0
    )
    public static let snowy = CharacterConfig(
        spriteSheet: "character_snowy_sheet",
        frameCount: 4, timePerFrame: 0.2,
        crossDuration: 3.5, cooldown: 10.0
    )

    public static func config(for type: WeatherType) -> CharacterConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}

// MARK: - Helpers

public extension CGFloat {
    func weatherClamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}

// MARK: - Weather Code Mapping (Open-Meteo WMO codes)

public enum WeatherCodeMapper {
    /// Maps WMO weather codes to our WeatherType
    /// See: https://open-meteo.com/en/docs#weathervariables
    public static func mapWeatherCode(_ code: Int) -> WeatherType {
        switch code {
        case 0, 1:
            return .sunny
        case 2, 3, 45, 48:
            return .cloudy
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            return .rainy
        case 71, 73, 75, 77, 85, 86:
            return .snowy
        default:
            return .cloudy
        }
    }
}

// MARK: - Intensity Logic

public enum IntensityLogic {
    public static func updateIntensity(current: CGFloat, isTouching: Bool) -> CGFloat {
        if isTouching {
            return min(1.0, current + IntensityConfig.rampRate)
        } else if current > 0 {
            return max(0.0, current - IntensityConfig.decayRate)
        }
        return current
    }
}

// MARK: - Lerp

public enum MathHelpers {
    public static func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t.weatherClamped(0, 1)
    }
}
