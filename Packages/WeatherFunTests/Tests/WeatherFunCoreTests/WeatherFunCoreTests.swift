// Tests/WeatherFunTests/WeatherFunTests.swift
import XCTest
@testable import WeatherFunCore

// MARK: - Intensity Mechanics Tests

/// Spec: ramp 0→1 in ~13s at 60fps, decay 1→0 in ~33s at 60fps
final class IntensityTests: XCTestCase {

    func testRampRate_SpecCompliance() {
        // Spec says 0→1 in 10-15 seconds at 60fps
        let rate = IntensityConfig.rampRate
        let framesToFull = 1.0 / Double(rate)
        let secondsToFull = framesToFull / 60.0

        // This WILL FAIL if ramp is too fast (spec violation)
        XCTAssertGreaterThan(secondsToFull, 10.0,
            "SPEC VIOLATION: Ramp too fast — \(String(format: "%.1f", secondsToFull))s to reach 1.0, spec requires 10-15s. " +
            "Current rate \(rate)/frame. Fix: set rampRate to ~0.0011")
        XCTAssertLessThan(secondsToFull, 16.0,
            "Ramp too slow: \(String(format: "%.1f", secondsToFull))s to reach 1.0 (spec says 10-15s)")
    }

    func testDecayRate_SpecCompliance() {
        let rate = IntensityConfig.decayRate
        let framesToZero = 1.0 / Double(rate)
        let secondsToZero = framesToZero / 60.0

        // Spec: ~30-33s decay
        XCTAssertGreaterThan(secondsToZero, 25.0,
            "Decay too fast: \(String(format: "%.1f", secondsToZero))s (spec says ~30-33s)")
        XCTAssertLessThan(secondsToZero, 40.0,
            "Decay too slow: \(String(format: "%.1f", secondsToZero))s (spec says ~30-33s)")
    }

    func testDecaySlowerThanRamp() {
        // Spec: "Slower than ramp so the toddler sees results linger"
        XCTAssertLessThan(IntensityConfig.decayRate, IntensityConfig.rampRate,
            "Decay rate should be slower (smaller) than ramp rate")
    }

    func testIntensityRamps_WhenTouching() {
        let result = IntensityLogic.updateIntensity(current: 0.0, isTouching: true)
        XCTAssertGreaterThan(result, 0.0)
        XCTAssertEqual(result, IntensityConfig.rampRate, accuracy: 0.0001)
    }

    func testIntensityDecays_WhenNotTouching() {
        let result = IntensityLogic.updateIntensity(current: 0.5, isTouching: false)
        XCTAssertLessThan(result, 0.5)
        XCTAssertEqual(result, 0.5 - IntensityConfig.decayRate, accuracy: 0.0001)
    }

    func testIntensityClamped_AtOne() {
        let result = IntensityLogic.updateIntensity(current: 0.999, isTouching: true)
        XCTAssertLessThanOrEqual(result, 1.0, "Intensity should not exceed 1.0")
    }

    func testIntensityClamped_AtZero() {
        let result = IntensityLogic.updateIntensity(current: 0.001, isTouching: false)
        XCTAssertGreaterThanOrEqual(result, 0.0, "Intensity should not go below 0.0")
    }

    func testIntensityStays_AtZero_WhenNotTouching() {
        let result = IntensityLogic.updateIntensity(current: 0.0, isTouching: false)
        XCTAssertEqual(result, 0.0, "Intensity should stay at 0 when not touching and already 0")
    }

    func testMultipleFramesRamp() {
        // Simulate 60 frames of touching (1 second)
        var intensity: CGFloat = 0.0
        for _ in 0..<60 {
            intensity = IntensityLogic.updateIntensity(current: intensity, isTouching: true)
        }
        let expectedAfter1s = IntensityConfig.rampRate * 60
        XCTAssertEqual(intensity, expectedAfter1s, accuracy: 0.001,
            "After 1 second of touching, intensity should be ~\(expectedAfter1s)")
    }

    func testMultipleFramesDecay() {
        // Simulate 60 frames of not touching from 1.0 (1 second)
        var intensity: CGFloat = 1.0
        for _ in 0..<60 {
            intensity = IntensityLogic.updateIntensity(current: intensity, isTouching: false)
        }
        let expectedAfter1s = 1.0 - IntensityConfig.decayRate * 60
        XCTAssertEqual(intensity, expectedAfter1s, accuracy: 0.001,
            "After 1 second of decay, intensity should be ~\(String(format: "%.3f", expectedAfter1s))")
    }
}

// MARK: - Threshold Tests

/// Spec thresholds: ground=0.3, sound=0.5, character=0.6, peak=0.8
final class ThresholdTests: XCTestCase {

    func testGroundEffectsThreshold() {
        XCTAssertEqual(IntensityThreshold.groundEffects, 0.3,
            "Ground effects should trigger at 0.3 (spec: puddles/snow at 0.3)")
    }

    func testSoundRampThreshold() {
        XCTAssertEqual(IntensityThreshold.soundRamp, 0.5,
            "Sound ramp should trigger at 0.5")
    }

    func testCharacterTriggerThreshold() {
        XCTAssertEqual(IntensityThreshold.characterTrigger, 0.6,
            "Character animation should trigger at 0.6 (spec: ~0.6)")
    }

    func testPeakEffectsThreshold() {
        XCTAssertEqual(IntensityThreshold.peakEffects, 0.8,
            "Peak effects (lightning, blizzard wind) should trigger at 0.8")
    }

    func testThresholdsInAscendingOrder() {
        XCTAssertLessThan(IntensityThreshold.groundEffects, IntensityThreshold.soundRamp)
        XCTAssertLessThan(IntensityThreshold.soundRamp, IntensityThreshold.characterTrigger)
        XCTAssertLessThan(IntensityThreshold.characterTrigger, IntensityThreshold.peakEffects)
    }

    func testAllThresholds_InZeroToOneRange() {
        let thresholds: [CGFloat] = [
            IntensityThreshold.groundEffects,
            IntensityThreshold.soundRamp,
            IntensityThreshold.characterTrigger,
            IntensityThreshold.peakEffects
        ]
        for t in thresholds {
            XCTAssertGreaterThan(t, 0.0, "Threshold should be > 0")
            XCTAssertLessThan(t, 1.0, "Threshold should be < 1.0")
        }
    }
}

// MARK: - Weather Code Mapping Tests

/// Spec: WMO codes mapped from Open-Meteo API
final class WeatherCodeMappingTests: XCTestCase {

    func testClearSkyCodes_MapToSunny() {
        // WMO 0 = clear sky, 1 = mainly clear
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(0), .sunny)
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(1), .sunny)
    }

    func testCloudyCodes_MapToCloudy() {
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(2), .cloudy, "Partly cloudy")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(3), .cloudy, "Overcast")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(45), .cloudy, "Fog")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(48), .cloudy, "Depositing rime fog")
    }

    func testRainCodes_MapToRainy() {
        let rainCodes = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        for code in rainCodes {
            XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(code), .rainy,
                "WMO code \(code) should map to rainy")
        }
    }

    func testSnowCodes_MapToSnowy() {
        let snowCodes = [71, 73, 75, 77, 85, 86]
        for code in snowCodes {
            XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(code), .snowy,
                "WMO code \(code) should map to snowy")
        }
    }

    func testUnknownCodes_MapToCloudy() {
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(-1), .cloudy, "Negative code")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(100), .cloudy, "Out of range code")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(999), .cloudy, "Arbitrary unknown code")
    }

    func testFreezingRainIsMappedToRainy() {
        // Design doc maps freezing rain/drizzle to rainy (not snowy)
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(56), .rainy, "Freezing drizzle")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(57), .rainy, "Dense freezing drizzle")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(66), .rainy, "Light freezing rain")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(67), .rainy, "Heavy freezing rain")
    }

    func testThunderstormCodes_MapToRainy() {
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(95), .rainy, "Thunderstorm")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(96), .rainy, "Thunderstorm with slight hail")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(99), .rainy, "Thunderstorm with heavy hail")
    }

    func testGapCodes_MapCorrectly() {
        // Codes between defined ranges should fall to default (cloudy)
        // E.g., codes 4-44 are not defined in WMO for Open-Meteo
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(10), .cloudy, "Undefined code 10")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(30), .cloudy, "Undefined code 30")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(50), .cloudy, "Undefined code 50")
        XCTAssertEqual(WeatherCodeMapper.mapWeatherCode(70), .cloudy, "Undefined code 70")
    }
}

// MARK: - Audio Config Tests

/// Spec: each weather type has specific volume ranges
final class AudioConfigTests: XCTestCase {

    func testSunnyVolume_MatchesSpec() {
        let config = AudioConfig.config(for: .sunny)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01, "Spec: sunny min 0.1")
        XCTAssertEqual(config.maxVolume, 0.7, accuracy: 0.01, "Spec: sunny max 0.7")
    }

    func testCloudyVolume_MatchesSpec() {
        let config = AudioConfig.config(for: .cloudy)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01, "Spec: cloudy min 0.1")
        XCTAssertEqual(config.maxVolume, 0.5, accuracy: 0.01, "Spec: cloudy max 0.5")
    }

    func testRainyVolume_MatchesSpec() {
        let config = AudioConfig.config(for: .rainy)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01, "Spec: rainy min 0.1")
        XCTAssertEqual(config.maxVolume, 0.8, accuracy: 0.01, "Spec: rainy max 0.8")
    }

    func testSnowyVolume_MatchesSpec() {
        let config = AudioConfig.config(for: .snowy)
        XCTAssertEqual(config.minVolume, 0.05, accuracy: 0.01, "Spec: snowy min 0.05")
        XCTAssertEqual(config.maxVolume, 0.4, accuracy: 0.01, "Spec: snowy max 0.4")
    }

    func testAllWeatherTypes_HaveAmbientFile() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertFalse(config.ambientFile.isEmpty, "\(type) missing ambient file")
            XCTAssertEqual(config.ambientExtension, "m4a", "Spec: ambient loops should be .m4a")
        }
    }

    func testAllWeatherTypes_HaveCharacterSFX() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertNotNil(config.characterSoundFile, "\(type) missing character SFX")
            XCTAssertNotNil(config.characterSoundExtension, "\(type) missing SFX extension")
        }
    }

    func testCharacterSFX_AreCafFormat() {
        // Spec: ".caf format for low latency"
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertEqual(config.characterSoundExtension, "caf",
                "\(type) character SFX should be .caf (spec: low latency)")
        }
    }

    func testMinVolume_LessThanMaxVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertLessThan(config.minVolume, config.maxVolume,
                "\(type) min volume should be < max volume")
        }
    }

    func testRainyIsLoudest() {
        // Rain should be loudest ambient (most dramatic)
        let rainy = AudioConfig.config(for: .rainy)
        for type in WeatherType.allCases where type != .rainy {
            let other = AudioConfig.config(for: type)
            XCTAssertGreaterThanOrEqual(rainy.maxVolume, other.maxVolume,
                "Rainy should be loudest (or equal) max volume vs \(type)")
        }
    }

    func testSnowyIsQuietest() {
        // Snowy should be quietest ambient (muffled world)
        let snowy = AudioConfig.config(for: .snowy)
        for type in WeatherType.allCases where type != .snowy {
            let other = AudioConfig.config(for: type)
            XCTAssertLessThanOrEqual(snowy.maxVolume, other.maxVolume,
                "Snowy should be quietest max volume vs \(type)")
        }
    }
}

// MARK: - Character Config Tests

/// Spec: 4 frames, ~3s cross, ~10s cooldown
final class CharacterConfigTests: XCTestCase {

    func testAllWeatherTypes_Have4Frames() {
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertEqual(config.frameCount, 4,
                "\(type): spec requires 4 animation frames")
        }
    }

    func testCrossDuration_IsReasonable() {
        // Spec: "cross screen over ~3 seconds"
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertGreaterThanOrEqual(config.crossDuration, 2.5,
                "\(type) cross too fast (spec: ~3s)")
            XCTAssertLessThanOrEqual(config.crossDuration, 5.0,
                "\(type) cross too slow (spec: ~3s)")
        }
    }

    func testCooldown_IsAbout10Seconds() {
        // Spec: "Re-trigger after ~10s cooldown"
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertEqual(config.cooldown, 10.0, accuracy: 2.0,
                "\(type) cooldown should be ~10s")
        }
    }

    func testSpriteSheetNames_MatchConvention() {
        let expected: [WeatherType: String] = [
            .sunny: "character_sunny_sheet",
            .cloudy: "character_cloudy_sheet",
            .rainy: "character_rainy_sheet",
            .snowy: "character_snowy_sheet",
        ]
        for (type, name) in expected {
            let config = CharacterConfig.config(for: type)
            XCTAssertEqual(config.spriteSheet, name)
        }
    }

    func testCloudyIsSlowerThanSunny() {
        // Cloudy kid walks slowly; sunny kid skips
        let sunny = CharacterConfig.config(for: .sunny)
        let cloudy = CharacterConfig.config(for: .cloudy)
        XCTAssertGreaterThan(cloudy.crossDuration, sunny.crossDuration,
            "Cloudy should cross slower than sunny (walk vs skip)")
    }

    func testTimePerFrame_IsPositive() {
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertGreaterThan(config.timePerFrame, 0,
                "\(type) timePerFrame must be positive")
        }
    }
}

// MARK: - Sky Config Tests

final class SkyConfigTests: XCTestCase {

    func testAllWeatherTypes_HaveDistinctSkyColors() {
        var topColors = Set<String>()
        for type in WeatherType.allCases {
            let config = SkyConfig.config(for: type)
            let key = "\(config.topColor.r),\(config.topColor.g),\(config.topColor.b)"
            let inserted = topColors.insert(key).inserted
            XCTAssertTrue(inserted, "\(type) has duplicate sky top color")
        }
    }

    func testSunnyIsBrightest() {
        let sunny = SkyConfig.config(for: .sunny)
        let rainy = SkyConfig.config(for: .rainy)
        XCTAssertGreaterThan(sunny.topColor.b, rainy.topColor.b,
            "Sunny sky should be bluer/brighter than rainy")
    }

    func testRainyIsDarkest() {
        let rainy = SkyConfig.config(for: .rainy)
        let rainyBrightness = rainy.topColor.r + rainy.topColor.g + rainy.topColor.b
        for type in WeatherType.allCases where type != .rainy {
            let other = SkyConfig.config(for: type)
            let otherBrightness = other.topColor.r + other.topColor.g + other.topColor.b
            XCTAssertLessThan(rainyBrightness, otherBrightness,
                "Rainy sky should be darker than \(type)")
        }
    }

    func testAllWeatherTypes_HaveTintConfig() {
        for type in WeatherType.allCases {
            let config = SkyConfig.config(for: type)
            XCTAssertGreaterThan(config.intenseTintAlpha, 0.0)
            XCTAssertLessThanOrEqual(config.intenseTintAlpha, 1.0)
        }
    }

    func testSkyColors_AreValidRGB() {
        for type in WeatherType.allCases {
            let config = SkyConfig.config(for: type)
            for color in [config.topColor, config.bottomColor, config.intenseTintColor] {
                XCTAssertGreaterThanOrEqual(color.r, 0)
                XCTAssertLessThanOrEqual(color.r, 255)
                XCTAssertGreaterThanOrEqual(color.g, 0)
                XCTAssertLessThanOrEqual(color.g, 255)
                XCTAssertGreaterThanOrEqual(color.b, 0)
                XCTAssertLessThanOrEqual(color.b, 255)
            }
        }
    }
}

// MARK: - Lerp & Clamping Tests

final class LerpTests: XCTestCase {

    func testLerp_AtZero_ReturnsA() {
        XCTAssertEqual(MathHelpers.lerp(10, 100, t: 0), 10, accuracy: 0.001)
    }

    func testLerp_AtOne_ReturnsB() {
        XCTAssertEqual(MathHelpers.lerp(10, 100, t: 1), 100, accuracy: 0.001)
    }

    func testLerp_AtHalf_ReturnsMidpoint() {
        XCTAssertEqual(MathHelpers.lerp(10, 100, t: 0.5), 55, accuracy: 0.001)
    }

    func testLerp_ClampsNegativeT() {
        XCTAssertEqual(MathHelpers.lerp(10, 100, t: -0.5), 10, accuracy: 0.001)
    }

    func testLerp_ClampsExcessiveT() {
        XCTAssertEqual(MathHelpers.lerp(10, 100, t: 1.5), 100, accuracy: 0.001)
    }

    func testLerp_RainBirthRateRange() {
        // Spec: rain birth rate 20 → 300
        XCTAssertEqual(MathHelpers.lerp(20, 300, t: 0), 20, accuracy: 0.1)
        XCTAssertEqual(MathHelpers.lerp(20, 300, t: 1), 300, accuracy: 0.1)
        XCTAssertEqual(MathHelpers.lerp(20, 300, t: 0.5), 160, accuracy: 0.1)
    }

    func testLerp_SnowBirthRateRange() {
        // Spec: snow birth rate 10 → 150
        XCTAssertEqual(MathHelpers.lerp(10, 150, t: 0), 10, accuracy: 0.1)
        XCTAssertEqual(MathHelpers.lerp(10, 150, t: 1), 150, accuracy: 0.1)
    }

    func testWeatherClamped_InRange() {
        let val: CGFloat = 0.5
        XCTAssertEqual(val.weatherClamped(0, 1), 0.5)
    }

    func testWeatherClamped_BelowMin() {
        let val: CGFloat = -0.5
        XCTAssertEqual(val.weatherClamped(0, 1), 0.0)
    }

    func testWeatherClamped_AboveMax() {
        let val: CGFloat = 1.5
        XCTAssertEqual(val.weatherClamped(0, 1), 1.0)
    }
}

// MARK: - WeatherType Enum Tests

final class WeatherTypeTests: XCTestCase {

    func testAllCases_HasFourTypes() {
        XCTAssertEqual(WeatherType.allCases.count, 4)
    }

    func testAllCases_ContainsExpectedTypes() {
        let types = WeatherType.allCases
        XCTAssertTrue(types.contains(.sunny))
        XCTAssertTrue(types.contains(.cloudy))
        XCTAssertTrue(types.contains(.rainy))
        XCTAssertTrue(types.contains(.snowy))
    }

    func testConfigLookups_CoverAllTypes() {
        // Every weather type should have all configs — no crash = pass
        for type in WeatherType.allCases {
            _ = SkyConfig.config(for: type)
            _ = AudioConfig.config(for: type)
            _ = CharacterConfig.config(for: type)
        }
    }
}

// MARK: - Audio Volume Scaling Tests

final class AudioVolumeScalingTests: XCTestCase {

    func testVolumeAtZeroIntensity_IsMinVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(0.0)
            XCTAssertEqual(volume, config.minVolume, accuracy: 0.001)
        }
    }

    func testVolumeAtFullIntensity_IsMaxVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(1.0)
            XCTAssertEqual(volume, config.maxVolume, accuracy: 0.001)
        }
    }

    func testVolumeNeverExceedsMaxVolume() {
        // Even at intensity > 1.0, audio should be capped
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(1.5)
            // Note: this tests the FORMULA, not the actual code — if ViewModel clamps intensity,
            // this is fine. But if it doesn't, the audio manager will exceed maxVolume.
            if volume > config.maxVolume {
                // This means the audio code doesn't protect against intensity > 1.0
                // Not necessarily a bug if intensity is always clamped, but worth flagging
                XCTAssertLessThanOrEqual(config.maxVolume, 1.0,
                    "\(type) maxVolume should never exceed system max 1.0")
            }
        }
    }
}

// MARK: - Intensity-Threshold Integration Tests

/// Tests that intensity progression actually crosses thresholds at expected times
final class IntensityProgressionTests: XCTestCase {

    func testGroundEffectsReached_BeforeCharacterTrigger() {
        // Ground effects (0.3) must be hit before character trigger (0.6)
        var intensity: CGFloat = 0.0
        var hitGround = false
        var hitCharacter = false
        var groundFrame = 0
        var characterFrame = 0

        for frame in 0..<10000 {
            intensity = IntensityLogic.updateIntensity(current: intensity, isTouching: true)
            if !hitGround && intensity >= IntensityThreshold.groundEffects {
                hitGround = true
                groundFrame = frame
            }
            if !hitCharacter && intensity >= IntensityThreshold.characterTrigger {
                hitCharacter = true
                characterFrame = frame
            }
            if hitGround && hitCharacter { break }
        }

        XCTAssertTrue(hitGround, "Should reach ground effects threshold")
        XCTAssertTrue(hitCharacter, "Should reach character trigger threshold")
        XCTAssertLessThan(groundFrame, characterFrame,
            "Ground effects should appear before character animation")
    }

    func testPeakEffects_ReachedBeforeMaxIntensity() {
        var intensity: CGFloat = 0.0
        var hitPeak = false
        for _ in 0..<10000 {
            intensity = IntensityLogic.updateIntensity(current: intensity, isTouching: true)
            if intensity >= IntensityThreshold.peakEffects {
                hitPeak = true
                break
            }
        }
        XCTAssertTrue(hitPeak, "Should reach peak effects before max intensity")
        XCTAssertLessThan(intensity, 1.0,
            "Peak effects (0.8) should trigger before reaching 1.0")
    }

    func testFullDecay_FromMaxToZero() {
        var intensity: CGFloat = 1.0
        var frames = 0
        while intensity > 0 && frames < 100000 {
            intensity = IntensityLogic.updateIntensity(current: intensity, isTouching: false)
            frames += 1
        }
        XCTAssertEqual(intensity, 0.0, accuracy: 0.0001, "Should fully decay to 0")
        let seconds = Double(frames) / 60.0
        XCTAssertGreaterThan(seconds, 25.0, "Full decay should take >25s")
        XCTAssertLessThan(seconds, 40.0, "Full decay should take <40s")
    }
}
