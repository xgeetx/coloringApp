// Packages/WeatherFun/Sources/WeatherFun/WeatherModels.swift
import Foundation
import CoreGraphics

// MARK: - Weather Type

enum WeatherType: String, CaseIterable {
    case sunny, cloudy, rainy, snowy
}

// MARK: - Intensity Thresholds

enum IntensityThreshold {
    static let groundEffects: CGFloat  = 0.3
    static let soundRamp: CGFloat      = 0.5
    static let characterTrigger: CGFloat = 0.6
    static let peakEffects: CGFloat    = 0.8
}

// MARK: - Intensity Config

struct IntensityConfig {
    /// Per-frame increment while touching (~60fps → 0→1 in ~13s)
    static let rampRate: CGFloat   = 0.005
    /// Per-frame decrement while not touching (1→0 in ~33s)
    static let decayRate: CGFloat  = 0.002
}

// MARK: - Sky Colors Per Weather Type

struct SkyConfig {
    let topColor: (r: Int, g: Int, b: Int)
    let bottomColor: (r: Int, g: Int, b: Int)
    /// How much the scene darkens/warms at max intensity (0–1)
    let intenseTintAlpha: CGFloat
    let intenseTintColor: (r: Int, g: Int, b: Int)

    static let sunny = SkyConfig(
        topColor: (70, 130, 220),
        bottomColor: (160, 210, 255),
        intenseTintAlpha: 0.3,
        intenseTintColor: (255, 200, 50)  // golden warm
    )
    static let cloudy = SkyConfig(
        topColor: (140, 155, 175),
        bottomColor: (190, 200, 210),
        intenseTintAlpha: 0.4,
        intenseTintColor: (80, 80, 90)  // dark gray
    )
    static let rainy = SkyConfig(
        topColor: (80, 95, 120),
        bottomColor: (130, 145, 165),
        intenseTintAlpha: 0.35,
        intenseTintColor: (40, 50, 70)  // dark blue-gray
    )
    static let snowy = SkyConfig(
        topColor: (180, 195, 210),
        bottomColor: (220, 225, 235),
        intenseTintAlpha: 0.25,
        intenseTintColor: (240, 240, 250)  // white-blue
    )

    static func config(for type: WeatherType) -> SkyConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}

// MARK: - Audio Config

struct AudioConfig {
    let ambientFile: String      // filename without extension
    let ambientExtension: String // "m4a"
    let minVolume: Float
    let maxVolume: Float
    let characterSoundFile: String?
    let characterSoundExtension: String?

    static let sunny = AudioConfig(
        ambientFile: "ambient_sunny", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.7,
        characterSoundFile: "sfx_giggle", characterSoundExtension: "caf"
    )
    static let cloudy = AudioConfig(
        ambientFile: "ambient_cloudy", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.5,
        characterSoundFile: "sfx_wind_gust", characterSoundExtension: "caf"
    )
    static let rainy = AudioConfig(
        ambientFile: "ambient_rainy", ambientExtension: "m4a",
        minVolume: 0.1, maxVolume: 0.8,
        characterSoundFile: "sfx_splash", characterSoundExtension: "caf"
    )
    static let snowy = AudioConfig(
        ambientFile: "ambient_snowy", ambientExtension: "m4a",
        minVolume: 0.05, maxVolume: 0.4,
        characterSoundFile: "sfx_snow_crunch", characterSoundExtension: "caf"
    )

    static func config(for type: WeatherType) -> AudioConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}

// MARK: - Character Config

struct CharacterConfig {
    let spriteSheet: String    // image name in bundle
    let frameCount: Int
    let timePerFrame: TimeInterval
    let crossDuration: TimeInterval
    let cooldown: TimeInterval

    static let sunny = CharacterConfig(
        spriteSheet: "character_sunny_sheet",
        frameCount: 4, timePerFrame: 0.15,
        crossDuration: 3.0, cooldown: 10.0
    )
    static let cloudy = CharacterConfig(
        spriteSheet: "character_cloudy_sheet",
        frameCount: 4, timePerFrame: 0.25,
        crossDuration: 4.0, cooldown: 10.0
    )
    static let rainy = CharacterConfig(
        spriteSheet: "character_rainy_sheet",
        frameCount: 4, timePerFrame: 0.12,
        crossDuration: 3.0, cooldown: 10.0
    )
    static let snowy = CharacterConfig(
        spriteSheet: "character_snowy_sheet",
        frameCount: 4, timePerFrame: 0.2,
        crossDuration: 3.5, cooldown: 10.0
    )

    static func config(for type: WeatherType) -> CharacterConfig {
        switch type {
        case .sunny:  return .sunny
        case .cloudy: return .cloudy
        case .rainy:  return .rainy
        case .snowy:  return .snowy
        }
    }
}
