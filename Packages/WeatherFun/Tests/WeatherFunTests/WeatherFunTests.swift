// Tests/WeatherFunTests/WeatherFunTests.swift
import XCTest
@testable import WeatherFun

// MARK: - Intensity Mechanics Tests

/// Spec: ramp 0→1 in ~13s at 60fps, decay 1→0 in ~33s at 60fps
final class IntensityTests: XCTestCase {

    @MainActor
    func testRampRate_ZeroToOneInAbout13Seconds() {
        // Spec says: intensity += 0.005/frame, 60fps → 200 frames → 3.33s? No.
        // 0.005 * 200 = 1.0, but 200 frames / 60fps = 3.33s.
        // Spec says ~13s which is 780 frames → 780 * 0.005 = 3.9 (capped at 1.0)
        // Actually the spec says 0→1 in ~13s. At 0.005/frame, 60fps:
        // 1.0 / 0.005 = 200 frames, 200/60 = 3.33s.
        // This is WAY faster than the spec's ~13s!
        // Spec 13s at 60fps = 780 frames → rate should be ~0.00128/frame
        let rate = IntensityConfig.rampRate
        let framesToFull = 1.0 / Double(rate)
        let secondsToFull = framesToFull / 60.0

        // Spec: 10-15 seconds. Current implementation is 0.005/frame = 3.33s.
        // This is a spec violation — flag it.
        XCTAssertGreaterThan(secondsToFull, 10.0,
            "Ramp too fast: \(secondsToFull)s to reach 1.0 (spec says 10-15s). Rate=\(rate)")
        XCTAssertLessThan(secondsToFull, 16.0,
            "Ramp too slow: \(secondsToFull)s to reach 1.0 (spec says 10-15s). Rate=\(rate)")
    }

    @MainActor
    func testDecayRate_OneToZeroInAbout33Seconds() {
        let rate = IntensityConfig.decayRate
        let framesToZero = 1.0 / Double(rate)
        let secondsToZero = framesToZero / 60.0

        // Spec: ~30s decay (design doc says ~33s from the ramp/decay math)
        XCTAssertGreaterThan(secondsToZero, 25.0,
            "Decay too fast: \(secondsToZero)s to reach 0.0 (spec says ~30-33s). Rate=\(rate)")
        XCTAssertLessThan(secondsToZero, 40.0,
            "Decay too slow: \(secondsToZero)s to reach 0.0 (spec says ~30-33s). Rate=\(rate)")
    }

    @MainActor
    func testDecaySlowerThanRamp() {
        // Spec: "Slower than ramp so the toddler sees results linger"
        XCTAssertLessThan(IntensityConfig.decayRate, IntensityConfig.rampRate,
            "Decay rate should be slower (smaller) than ramp rate")
    }

    @MainActor
    func testIntensityRamps_WhenTouching() {
        let vm = WeatherViewModel()
        vm.intensity = 0.0
        vm.isTouching = true
        vm.updateIntensity()
        XCTAssertGreaterThan(vm.intensity, 0.0, "Intensity should increase when touching")
        XCTAssertEqual(vm.intensity, IntensityConfig.rampRate, accuracy: 0.0001)
    }

    @MainActor
    func testIntensityDecays_WhenNotTouching() {
        let vm = WeatherViewModel()
        vm.intensity = 0.5
        vm.isTouching = false
        vm.updateIntensity()
        XCTAssertLessThan(vm.intensity, 0.5, "Intensity should decrease when not touching")
        XCTAssertEqual(vm.intensity, 0.5 - IntensityConfig.decayRate, accuracy: 0.0001)
    }

    @MainActor
    func testIntensityClamped_AtOne() {
        let vm = WeatherViewModel()
        vm.intensity = 0.999
        vm.isTouching = true
        vm.updateIntensity()
        XCTAssertLessThanOrEqual(vm.intensity, 1.0, "Intensity should not exceed 1.0")
    }

    @MainActor
    func testIntensityClamped_AtZero() {
        let vm = WeatherViewModel()
        vm.intensity = 0.001
        vm.isTouching = false
        vm.updateIntensity()
        XCTAssertGreaterThanOrEqual(vm.intensity, 0.0, "Intensity should not go below 0.0")
    }

    @MainActor
    func testIntensityStays_AtZero_WhenNotTouching() {
        let vm = WeatherViewModel()
        vm.intensity = 0.0
        vm.isTouching = false
        vm.updateIntensity()
        XCTAssertEqual(vm.intensity, 0.0, "Intensity should stay at 0 when not touching and already 0")
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
}

// MARK: - Weather Code Mapping Tests

/// Spec: WMO codes mapped from Open-Meteo API
final class WeatherCodeMappingTests: XCTestCase {

    @MainActor
    func testClearSkyCodes_MapToSunny() {
        let vm = WeatherViewModel()
        // WMO 0 = clear sky, 1 = mainly clear
        XCTAssertEqual(vm.mapWeatherCode(0), .sunny)
        XCTAssertEqual(vm.mapWeatherCode(1), .sunny)
    }

    @MainActor
    func testCloudyCodes_MapToCloudy() {
        let vm = WeatherViewModel()
        XCTAssertEqual(vm.mapWeatherCode(2), .cloudy, "Partly cloudy")
        XCTAssertEqual(vm.mapWeatherCode(3), .cloudy, "Overcast")
        XCTAssertEqual(vm.mapWeatherCode(45), .cloudy, "Fog")
        XCTAssertEqual(vm.mapWeatherCode(48), .cloudy, "Depositing rime fog")
    }

    @MainActor
    func testRainCodes_MapToRainy() {
        let vm = WeatherViewModel()
        // Drizzle
        XCTAssertEqual(vm.mapWeatherCode(51), .rainy, "Light drizzle")
        XCTAssertEqual(vm.mapWeatherCode(53), .rainy, "Moderate drizzle")
        XCTAssertEqual(vm.mapWeatherCode(55), .rainy, "Dense drizzle")
        // Freezing drizzle
        XCTAssertEqual(vm.mapWeatherCode(56), .rainy, "Light freezing drizzle")
        XCTAssertEqual(vm.mapWeatherCode(57), .rainy, "Dense freezing drizzle")
        // Rain
        XCTAssertEqual(vm.mapWeatherCode(61), .rainy, "Slight rain")
        XCTAssertEqual(vm.mapWeatherCode(63), .rainy, "Moderate rain")
        XCTAssertEqual(vm.mapWeatherCode(65), .rainy, "Heavy rain")
        // Freezing rain
        XCTAssertEqual(vm.mapWeatherCode(66), .rainy, "Light freezing rain")
        XCTAssertEqual(vm.mapWeatherCode(67), .rainy, "Heavy freezing rain")
        // Rain showers
        XCTAssertEqual(vm.mapWeatherCode(80), .rainy, "Slight rain showers")
        XCTAssertEqual(vm.mapWeatherCode(81), .rainy, "Moderate rain showers")
        XCTAssertEqual(vm.mapWeatherCode(82), .rainy, "Violent rain showers")
        // Thunderstorm
        XCTAssertEqual(vm.mapWeatherCode(95), .rainy, "Thunderstorm")
        XCTAssertEqual(vm.mapWeatherCode(96), .rainy, "Thunderstorm with slight hail")
        XCTAssertEqual(vm.mapWeatherCode(99), .rainy, "Thunderstorm with heavy hail")
    }

    @MainActor
    func testSnowCodes_MapToSnowy() {
        let vm = WeatherViewModel()
        XCTAssertEqual(vm.mapWeatherCode(71), .snowy, "Slight snow fall")
        XCTAssertEqual(vm.mapWeatherCode(73), .snowy, "Moderate snow fall")
        XCTAssertEqual(vm.mapWeatherCode(75), .snowy, "Heavy snow fall")
        XCTAssertEqual(vm.mapWeatherCode(77), .snowy, "Snow grains")
        XCTAssertEqual(vm.mapWeatherCode(85), .snowy, "Slight snow showers")
        XCTAssertEqual(vm.mapWeatherCode(86), .snowy, "Heavy snow showers")
    }

    @MainActor
    func testUnknownCodes_MapToCloudy() {
        let vm = WeatherViewModel()
        // Unknown codes should default to cloudy (safe fallback)
        XCTAssertEqual(vm.mapWeatherCode(-1), .cloudy, "Negative code")
        XCTAssertEqual(vm.mapWeatherCode(100), .cloudy, "Out of range code")
        XCTAssertEqual(vm.mapWeatherCode(999), .cloudy, "Arbitrary unknown code")
    }

    @MainActor
    func testFreezingRainIsMappedConsistently() {
        let vm = WeatherViewModel()
        // Design doc maps freezing rain to rainy (not snowy) — verify
        // WMO 56, 57 = freezing drizzle; 66, 67 = freezing rain
        XCTAssertEqual(vm.mapWeatherCode(56), .rainy, "Freezing drizzle → rainy (not snowy)")
        XCTAssertEqual(vm.mapWeatherCode(57), .rainy, "Dense freezing drizzle → rainy (not snowy)")
        XCTAssertEqual(vm.mapWeatherCode(66), .rainy, "Light freezing rain → rainy (not snowy)")
        XCTAssertEqual(vm.mapWeatherCode(67), .rainy, "Heavy freezing rain → rainy (not snowy)")
    }
}

// MARK: - Audio Config Tests

/// Spec: each weather type has specific volume ranges
final class AudioConfigTests: XCTestCase {

    func testSunnyVolume_MatchesSpec() {
        // Spec: sunny ambient 0.1 → 0.7
        let config = AudioConfig.config(for: .sunny)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01, "Sunny min volume should be 0.1")
        XCTAssertEqual(config.maxVolume, 0.7, accuracy: 0.01, "Sunny max volume should be 0.7")
    }

    func testCloudyVolume_MatchesSpec() {
        // Spec: cloudy ambient 0.1 → 0.5
        let config = AudioConfig.config(for: .cloudy)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01)
        XCTAssertEqual(config.maxVolume, 0.5, accuracy: 0.01)
    }

    func testRainyVolume_MatchesSpec() {
        // Spec: rainy ambient 0.1 → 0.8
        let config = AudioConfig.config(for: .rainy)
        XCTAssertEqual(config.minVolume, 0.1, accuracy: 0.01)
        XCTAssertEqual(config.maxVolume, 0.8, accuracy: 0.01)
    }

    func testSnowyVolume_MatchesSpec() {
        // Spec: snowy ambient 0.05 → 0.4
        let config = AudioConfig.config(for: .snowy)
        XCTAssertEqual(config.minVolume, 0.05, accuracy: 0.01)
        XCTAssertEqual(config.maxVolume, 0.4, accuracy: 0.01)
    }

    func testAllWeatherTypes_HaveAmbientFile() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertFalse(config.ambientFile.isEmpty,
                "\(type) should have an ambient audio file")
            XCTAssertEqual(config.ambientExtension, "m4a",
                "Ambient loops should be .m4a format (spec)")
        }
    }

    func testAllWeatherTypes_HaveCharacterSFX() {
        // Spec: each weather type has a character sound
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertNotNil(config.characterSoundFile,
                "\(type) should have a character sound file")
            XCTAssertNotNil(config.characterSoundExtension,
                "\(type) should have a character sound extension")
        }
    }

    func testCharacterSFX_AreCafFormat() {
        // Spec: ".caf format for low latency"
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertEqual(config.characterSoundExtension, "caf",
                "\(type) character SFX should be .caf format (spec: low latency)")
        }
    }

    func testMinVolume_LessThanMaxVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            XCTAssertLessThan(config.minVolume, config.maxVolume,
                "\(type) min volume should be less than max volume")
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
                "\(type) character should have 4 animation frames (spec)")
        }
    }

    func testCrossDuration_IsReasonable() {
        // Spec: "cross screen over ~3 seconds"
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertGreaterThanOrEqual(config.crossDuration, 2.5,
                "\(type) cross duration too fast (spec: ~3s)")
            XCTAssertLessThanOrEqual(config.crossDuration, 5.0,
                "\(type) cross duration too slow (spec: ~3s)")
        }
    }

    func testCooldown_IsAbout10Seconds() {
        // Spec: "Re-trigger after ~10s cooldown"
        for type in WeatherType.allCases {
            let config = CharacterConfig.config(for: type)
            XCTAssertEqual(config.cooldown, 10.0, accuracy: 2.0,
                "\(type) cooldown should be ~10s (spec)")
        }
    }

    func testSpriteSheetNames_MatchExpectedConvention() {
        let expected: [WeatherType: String] = [
            .sunny: "character_sunny_sheet",
            .cloudy: "character_cloudy_sheet",
            .rainy: "character_rainy_sheet",
            .snowy: "character_snowy_sheet",
        ]
        for (type, name) in expected {
            let config = CharacterConfig.config(for: type)
            XCTAssertEqual(config.spriteSheet, name,
                "\(type) sprite sheet should be named \(name)")
        }
    }

    func testCloudyIsSlowerThanSunny() {
        // Cloudy kid walks slowly; sunny kid skips — cloudy should have longer cross duration
        let sunny = CharacterConfig.config(for: .sunny)
        let cloudy = CharacterConfig.config(for: .cloudy)
        XCTAssertGreaterThan(cloudy.crossDuration, sunny.crossDuration,
            "Cloudy character should be slower than sunny (walks vs skips)")
    }
}

// MARK: - Sky Config Tests

final class SkyConfigTests: XCTestCase {

    func testAllWeatherTypes_HaveDistinctSkyColors() {
        let configs = WeatherType.allCases.map { SkyConfig.config(for: $0) }
        // Each weather type should have unique top colors
        var topColors = Set<String>()
        for (i, config) in configs.enumerated() {
            let key = "\(config.topColor.r),\(config.topColor.g),\(config.topColor.b)"
            let inserted = topColors.insert(key).inserted
            XCTAssertTrue(inserted,
                "\(WeatherType.allCases[i]) has duplicate sky top color: \(key)")
        }
    }

    func testSunnyIsBrightest() {
        // Sunny should have the brightest (highest blue channel) sky
        let sunny = SkyConfig.config(for: .sunny)
        let rainy = SkyConfig.config(for: .rainy)
        XCTAssertGreaterThan(sunny.topColor.b, rainy.topColor.b,
            "Sunny sky should be bluer/brighter than rainy")
    }

    func testRainyIsDarkest() {
        // Rainy should have the darkest sky
        let rainy = SkyConfig.config(for: .rainy)
        for type in WeatherType.allCases where type != .rainy {
            let other = SkyConfig.config(for: type)
            let rainyBrightness = rainy.topColor.r + rainy.topColor.g + rainy.topColor.b
            let otherBrightness = other.topColor.r + other.topColor.g + other.topColor.b
            XCTAssertLessThan(rainyBrightness, otherBrightness,
                "Rainy sky should be darker than \(type)")
        }
    }

    func testAllWeatherTypes_HaveTintConfig() {
        for type in WeatherType.allCases {
            let config = SkyConfig.config(for: type)
            XCTAssertGreaterThan(config.intenseTintAlpha, 0.0,
                "\(type) should have non-zero tint alpha")
            XCTAssertLessThanOrEqual(config.intenseTintAlpha, 1.0,
                "\(type) tint alpha should not exceed 1.0")
        }
    }
}

// MARK: - Lerp & Clamping Tests

final class LerpTests: XCTestCase {

    func testLerp_AtZero_ReturnsA() {
        XCTAssertEqual(ParticleFactory.lerp(10, 100, t: 0), 10, accuracy: 0.001)
    }

    func testLerp_AtOne_ReturnsB() {
        XCTAssertEqual(ParticleFactory.lerp(10, 100, t: 1), 100, accuracy: 0.001)
    }

    func testLerp_AtHalf_ReturnsMidpoint() {
        XCTAssertEqual(ParticleFactory.lerp(10, 100, t: 0.5), 55, accuracy: 0.001)
    }

    func testLerp_ClampsNegativeT() {
        // t < 0 should clamp to 0 → return a
        XCTAssertEqual(ParticleFactory.lerp(10, 100, t: -0.5), 10, accuracy: 0.001)
    }

    func testLerp_ClampsExcessiveT() {
        // t > 1 should clamp to 1 → return b
        XCTAssertEqual(ParticleFactory.lerp(10, 100, t: 1.5), 100, accuracy: 0.001)
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

// MARK: - Particle Factory Tests

final class ParticleFactoryTests: XCTestCase {

    func testRain_BirthRateScalesWithIntensity() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let lowRain = ParticleFactory.makeRain(sceneSize: sceneSize, intensity: 0.0)
        let highRain = ParticleFactory.makeRain(sceneSize: sceneSize, intensity: 1.0)
        XCTAssertEqual(lowRain.particleBirthRate, 20, accuracy: 1,
            "Rain at intensity 0 should have ~20 birth rate")
        XCTAssertEqual(highRain.particleBirthRate, 300, accuracy: 1,
            "Rain at intensity 1 should have ~300 birth rate")
    }

    func testSnow_BirthRateScalesWithIntensity() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let lowSnow = ParticleFactory.makeSnow(sceneSize: sceneSize, intensity: 0.0)
        let highSnow = ParticleFactory.makeSnow(sceneSize: sceneSize, intensity: 1.0)
        XCTAssertEqual(lowSnow.particleBirthRate, 10, accuracy: 1)
        XCTAssertEqual(highSnow.particleBirthRate, 150, accuracy: 1)
    }

    func testSnow_SlowerThanRain() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let rain = ParticleFactory.makeRain(sceneSize: sceneSize, intensity: 0.5)
        let snow = ParticleFactory.makeSnow(sceneSize: sceneSize, intensity: 0.5)
        XCTAssertGreaterThan(rain.particleSpeed, snow.particleSpeed,
            "Rain should fall faster than snow")
    }

    func testSunRays_ZeroBirthRate_BelowThreshold() {
        // Sun rays should not appear at low intensity (below 0.3)
        let sceneSize = CGSize(width: 1024, height: 768)
        let lowSun = ParticleFactory.makeSunRays(sceneSize: sceneSize, intensity: 0.0)
        XCTAssertEqual(lowSun.particleBirthRate, 0, accuracy: 0.1,
            "Sun rays should have 0 birth rate at intensity 0")
    }

    func testSunRays_PositiveBirthRate_AboveThreshold() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let highSun = ParticleFactory.makeSunRays(sceneSize: sceneSize, intensity: 1.0)
        XCTAssertGreaterThan(highSun.particleBirthRate, 0,
            "Sun rays should have positive birth rate at intensity 1.0")
    }

    func testRain_EmitsFromTopOfScreen() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let rain = ParticleFactory.makeRain(sceneSize: sceneSize, intensity: 0.5)
        XCTAssertGreaterThan(rain.position.y, sceneSize.height / 2 - 10,
            "Rain should emit from top of screen")
    }

    func testRain_FallsDownward() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let rain = ParticleFactory.makeRain(sceneSize: sceneSize, intensity: 0.5)
        // emissionAngle of -.pi/2 means straight down
        XCTAssertEqual(rain.emissionAngle, -.pi / 2, accuracy: 0.3,
            "Rain should emit downward (-.pi/2)")
    }
}

// MARK: - ViewModel State Tests

final class ViewModelTests: XCTestCase {

    @MainActor
    func testDefaultZipCode() {
        // Clear any stored value to test true default
        UserDefaults.standard.removeObject(forKey: "weatherZipCode")
        let vm = WeatherViewModel()
        XCTAssertEqual(vm.zipCode, "43123",
            "Default zip should be 43123 (user requirement)")
    }

    @MainActor
    func testDefaultWeatherType_IsSunny() {
        let vm = WeatherViewModel()
        XCTAssertEqual(vm.weatherType, .sunny,
            "Default weather type should be sunny")
    }

    @MainActor
    func testDefaultIntensity_IsZero() {
        let vm = WeatherViewModel()
        XCTAssertEqual(vm.intensity, 0.0,
            "Default intensity should be 0.0")
    }

    @MainActor
    func testDefaultTouching_IsFalse() {
        let vm = WeatherViewModel()
        XCTAssertFalse(vm.isTouching,
            "Default touch state should be false")
    }

    @MainActor
    func testWeatherOverride_DefaultNil() {
        let vm = WeatherViewModel()
        XCTAssertNil(vm.weatherOverride,
            "Weather override should default to nil (use real weather)")
    }

    @MainActor
    func testWeatherOverride_SkipsApiFetch() {
        let vm = WeatherViewModel()
        vm.weatherOverride = .snowy
        vm.fetchWeather()
        // When override is set, fetchWeather should apply it immediately
        XCTAssertEqual(vm.weatherType, .snowy,
            "With override set, fetchWeather should use the override")
    }

    @MainActor
    func testZipValidation_RejectsShortZip() {
        let vm = WeatherViewModel()
        vm.zipCode = "123"
        vm.weatherOverride = nil
        vm.fetchWeather()
        XCTAssertNotNil(vm.zipError,
            "Should show error for zip shorter than 5 digits")
    }

    @MainActor
    func testZipValidation_RejectsNonNumeric() {
        let vm = WeatherViewModel()
        vm.zipCode = "abcde"
        vm.weatherOverride = nil
        vm.fetchWeather()
        XCTAssertNotNil(vm.zipError,
            "Should show error for non-numeric zip")
    }

    @MainActor
    func testZipValidation_Accepts5Digits() {
        let vm = WeatherViewModel()
        vm.zipCode = "43123"
        vm.weatherOverride = nil
        vm.zipError = "previous error"
        vm.fetchWeather()
        XCTAssertNil(vm.zipError,
            "Should clear error for valid 5-digit zip")
    }
}

// MARK: - WeatherType Enum Tests

final class WeatherTypeTests: XCTestCase {

    func testAllCases_HasFourTypes() {
        XCTAssertEqual(WeatherType.allCases.count, 4,
            "Should have exactly 4 weather types: sunny, cloudy, rainy, snowy")
    }

    func testAllCases_ContainsExpectedTypes() {
        let types = WeatherType.allCases
        XCTAssertTrue(types.contains(.sunny))
        XCTAssertTrue(types.contains(.cloudy))
        XCTAssertTrue(types.contains(.rainy))
        XCTAssertTrue(types.contains(.snowy))
    }

    func testConfigLookups_CoverAllTypes() {
        // Every weather type should have all configs (sky, audio, character)
        for type in WeatherType.allCases {
            _ = SkyConfig.config(for: type)
            _ = AudioConfig.config(for: type)
            _ = CharacterConfig.config(for: type)
            // No crash = pass
        }
    }
}

// MARK: - Audio Volume Scaling Tests

final class AudioVolumeScalingTests: XCTestCase {

    func testVolumeAtZeroIntensity_IsMinVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(0.0)
            XCTAssertEqual(volume, config.minVolume, accuracy: 0.001,
                "\(type) volume at intensity 0 should be minVolume")
        }
    }

    func testVolumeAtFullIntensity_IsMaxVolume() {
        for type in WeatherType.allCases {
            let config = AudioConfig.config(for: type)
            let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(1.0)
            XCTAssertEqual(volume, config.maxVolume, accuracy: 0.001,
                "\(type) volume at intensity 1 should be maxVolume")
        }
    }

    func testVolumeScalesLinearly() {
        let config = AudioConfig.config(for: .rainy)
        let vol25 = config.minVolume + (config.maxVolume - config.minVolume) * 0.25
        let vol75 = config.minVolume + (config.maxVolume - config.minVolume) * 0.75
        let diff1 = vol25 - config.minVolume
        let diff2 = vol75 - vol25
        // Both spans should be equal (linear)
        XCTAssertEqual(diff1, diff2 / 2, accuracy: 0.01,
            "Volume should scale linearly with intensity")
    }
}
