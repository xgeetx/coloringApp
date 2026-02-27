# Weather Fun Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Build a SpriteKit + SwiftUI weather app where toddlers scribble to intensify real weather fetched via WeatherKit.

**Architecture:** Swift package at `Packages/WeatherFun/` with 6 source files. SpriteKit `SKScene` renders the animated weather scene, wrapped in SwiftUI `SpriteView`. `WeatherViewModel` bridges touch input (intensity) and WeatherKit data to the scene. Audio via `AVAudioPlayer` for ambient loops + one-shots.

**Tech Stack:** SwiftUI, SpriteKit, WeatherKit (iOS 16+), CoreLocation (CLGeocoder), AVFoundation

**Design doc:** `docs/plans/2026-02-27-weather-fun-design.md`

---

### Task 0: Create Package Skeleton & Verify Build

**Files:**
- Create: `Packages/WeatherFun/Package.swift`
- Create: `Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift`
- Modify: `ColoringApp/AppRegistry.swift`

**Step 1: Create Package.swift**

```swift
// Packages/WeatherFun/Package.swift
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WeatherFun",
    platforms: [.iOS(.v15)],
    products: [.library(name: "WeatherFun", targets: ["WeatherFun"])],
    targets: [
        .target(
            name: "WeatherFun",
            resources: [.process("Resources")]
        )
    ]
)
```

**Step 2: Create minimal WeatherView.swift**

```swift
// Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
import SwiftUI

public struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Color(r: 135, g: 206, b: 235) // sky blue placeholder
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("🏠")
                            .font(.system(size: 36))
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.7)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                Spacer()
                Text("Weather Fun")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
}

// MARK: - Private Extensions

private extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1
        )
    }
}
```

**Step 3: Create empty Resources directory**

```bash
mkdir -p Packages/WeatherFun/Sources/WeatherFun/Resources
touch Packages/WeatherFun/Sources/WeatherFun/Resources/.gitkeep
```

**Step 4: Add import + registry entry to AppRegistry.swift**

Add `import WeatherFun` at top. Add new entry after the TraceFun entry:

```swift
MiniAppDescriptor(
    id: "weather",
    displayName: "Weather Fun",
    subtitle: "Paint the Weather!",
    icon: "🌤️",
    tileColor: Color(r: 180, g: 220, b: 255),
    isAvailable: true,
    makeRootView: { AnyView(WeatherView()) }
),
```

**Step 5: Commit + push, register package on Mac**

```bash
git add Packages/WeatherFun/ ColoringApp/AppRegistry.swift
git commit -m "feat: WeatherFun package skeleton with placeholder view"
git push
```

Then SSH to Mac and run the Python pbxproj registration script from CLAUDE.md with:
- `PKG_NAME = "WeatherFun"`
- `PKG_PATH = "Packages/WeatherFun"`
- `PKG_UUID = "E1E2E3E4E5E6E7E8E9F0F1F2"`
- `PROD_UUID = "F1F2F3F4F5F6F7F8F9A0A1A2"`

Build on Mac to verify:
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

**Step 6: Patch pbxproj back to WSL**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git add ColoringFun.xcodeproj/project.pbxproj && git commit -m 'chore: register WeatherFun local package'"
ssh claude@192.168.50.251 "git -C ~/Dev/coloringApp format-patch HEAD~1 --stdout" > /tmp/patch.patch
git am /tmp/patch.patch && git push
```

---

### Task 1: WeatherModels — Types, Thresholds, Config

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/WeatherModels.swift`

**Step 1: Create WeatherModels.swift**

```swift
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
```

**Step 2: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherModels.swift
git commit -m "feat(weather): add WeatherModels — types, thresholds, configs"
```

---

### Task 2: WeatherViewModel — Intensity State, Decay Timer, WeatherKit Fetch

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/WeatherViewModel.swift`

**Step 1: Create WeatherViewModel.swift**

```swift
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

enum WeatherServiceBridge {
    @available(iOS 16, *)
    static func fetchCurrent(location: CLLocation) async throws -> WeatherType {
        // WeatherKit import is gated behind availability
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
            // cloudy, partlyCloudy, mostlyCloudy, foggy, haze, smoky, etc.
            return .cloudy
        }
    }
}
```

**Note:** The `import WeatherKit` is implicit through the `WeatherService` and `WeatherCondition` types which are only accessed inside `@available(iOS 16, *)` blocks. The Package.swift may need a conditional framework import — if the build fails, add `.systemLibrary(name: "WeatherKit")` or handle via `#if canImport(WeatherKit)`.

**Step 2: Verify build on Mac**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

If WeatherKit import fails, wrap with `#if canImport(WeatherKit)` and provide a stub fallback.

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherViewModel.swift
git commit -m "feat(weather): add WeatherViewModel — intensity, decay, WeatherKit fetch"
```

---

### Task 3: WeatherScene — SpriteKit Scene with Sky Gradient & Background

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift`

**Step 1: Create WeatherScene.swift**

This is the core SpriteKit scene. Start with sky gradient + background image + intensity-driven tinting. Particles and characters are added in Tasks 4-5.

```swift
// Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
import SpriteKit

class WeatherScene: SKScene {

    // MARK: - References
    weak var viewModel: WeatherViewModel?

    // MARK: - Nodes
    private var skyTop: SKSpriteNode!
    private var skyBottom: SKSpriteNode!
    private var backgroundSprite: SKSpriteNode!
    private var tintOverlay: SKSpriteNode!
    private var groundEffectsNode: SKNode!
    private var particleLayer: SKNode!
    private var characterLayer: SKNode!

    // MARK: - State
    private var currentWeatherType: WeatherType = .sunny
    private var currentIntensity: CGFloat = 0.0

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill

        setupSky()
        setupBackground()
        setupTintOverlay()

        // Container nodes for layered content
        groundEffectsNode = SKNode()
        groundEffectsNode.zPosition = 20
        addChild(groundEffectsNode)

        particleLayer = SKNode()
        particleLayer.zPosition = 30
        addChild(particleLayer)

        characterLayer = SKNode()
        characterLayer.zPosition = 40
        addChild(characterLayer)
    }

    // MARK: - Sky

    private func setupSky() {
        // Two colored rectangles to approximate a gradient
        let halfH = UIScreen.main.bounds.height / 2

        skyTop = SKSpriteNode(color: .clear, size: CGSize(width: UIScreen.main.bounds.width, height: halfH))
        skyTop.position = CGPoint(x: 0, y: halfH / 2)
        skyTop.zPosition = -10
        addChild(skyTop)

        skyBottom = SKSpriteNode(color: .clear, size: CGSize(width: UIScreen.main.bounds.width, height: halfH))
        skyBottom.position = CGPoint(x: 0, y: -halfH / 2)
        skyBottom.zPosition = -10
        addChild(skyBottom)

        applySkyColors(for: .sunny, intensity: 0)
    }

    private func applySkyColors(for weather: WeatherType, intensity: CGFloat) {
        let config = SkyConfig.config(for: weather)
        let topC = UIColor(
            red: CGFloat(config.topColor.r) / 255,
            green: CGFloat(config.topColor.g) / 255,
            blue: CGFloat(config.topColor.b) / 255,
            alpha: 1
        )
        let botC = UIColor(
            red: CGFloat(config.bottomColor.r) / 255,
            green: CGFloat(config.bottomColor.g) / 255,
            blue: CGFloat(config.bottomColor.b) / 255,
            alpha: 1
        )
        skyTop.color = topC
        skyTop.colorBlendFactor = 1.0
        skyBottom.color = botC
        skyBottom.colorBlendFactor = 1.0
    }

    // MARK: - Background Image

    private func setupBackground() {
        // Try to load the DALL-E generated neighborhood image
        if let _ = UIImage(named: "neighborhood_base", in: Bundle.module, compatibleWith: nil) {
            let texture = SKTexture(imageNamed: "neighborhood_base")
            backgroundSprite = SKSpriteNode(texture: texture)
        } else {
            // Placeholder: green ground rectangle
            backgroundSprite = SKSpriteNode(color: UIColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1), size: CGSize(width: 800, height: 300))
        }
        backgroundSprite.position = CGPoint(x: 0, y: -size.height * 0.15)
        backgroundSprite.zPosition = 0
        backgroundSprite.setScale(min(size.width / backgroundSprite.size.width, 1.0))
        addChild(backgroundSprite)
    }

    // MARK: - Tint Overlay

    private func setupTintOverlay() {
        tintOverlay = SKSpriteNode(color: .clear, size: self.size)
        tintOverlay.zPosition = 50
        tintOverlay.alpha = 0
        addChild(tintOverlay)
    }

    private func updateTintOverlay(for weather: WeatherType, intensity: CGFloat) {
        let config = SkyConfig.config(for: weather)
        let tintC = UIColor(
            red: CGFloat(config.intenseTintColor.r) / 255,
            green: CGFloat(config.intenseTintColor.g) / 255,
            blue: CGFloat(config.intenseTintColor.b) / 255,
            alpha: 1
        )
        tintOverlay.color = tintC
        tintOverlay.colorBlendFactor = 1.0
        tintOverlay.alpha = config.intenseTintAlpha * intensity
    }

    // MARK: - Frame Update

    override func update(_ currentTime: TimeInterval) {
        guard let vm = viewModel else { return }

        let weather = vm.weatherType
        let intensity = vm.intensity

        // Update sky if weather type changed
        if weather != currentWeatherType {
            currentWeatherType = weather
            applySkyColors(for: weather, intensity: intensity)
        }

        // Update intensity-driven effects
        updateTintOverlay(for: weather, intensity: intensity)
        currentIntensity = intensity
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        let w = size.width
        let h = size.height
        let halfH = h / 2

        skyTop?.size = CGSize(width: w, height: halfH)
        skyTop?.position = CGPoint(x: 0, y: halfH / 2)
        skyBottom?.size = CGSize(width: w, height: halfH)
        skyBottom?.position = CGPoint(x: 0, y: -halfH / 2)
        tintOverlay?.size = size

        if let bg = backgroundSprite {
            bg.setScale(min(w / bg.texture!.size().width, 1.0))
            bg.position = CGPoint(x: 0, y: -h * 0.15)
        }
    }
}
```

**Step 2: Verify build**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild ... build 2>&1 | grep -E '(error:|BUILD)'"
```

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
git commit -m "feat(weather): add WeatherScene — sky gradient, background, tint overlay"
```

---

### Task 4: ParticleFactory — Rain, Snow, Sun Rays, Cloud Drift

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/ParticleFactory.swift`
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift`

**Step 1: Create ParticleFactory.swift**

Programmatic `SKEmitterNode` creation (no .sks files needed — avoids asset management complexity).

```swift
// Packages/WeatherFun/Sources/WeatherFun/ParticleFactory.swift
import SpriteKit

enum ParticleFactory {

    // MARK: - Rain

    static func makeRain(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(20, 300, t: intensity)
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5

        // White-blue raindrop
        emitter.particleColor = UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.7)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.3, 0.8, t: intensity)
        emitter.particleScale = 0.05
        emitter.particleScaleRange = 0.02

        // Fall downward with slight angle
        emitter.emissionAngle = -.pi / 2  // straight down
        emitter.emissionAngleRange = 0.2
        emitter.particleSpeed = lerp(300, 600, t: intensity)
        emitter.particleSpeedRange = 100

        // Emit across top of screen
        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 50)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width * 1.2, dy: 0)

        // Use built-in square shape
        emitter.particleTexture = SKTexture(imageNamed: "spark") // SpriteKit built-in fallback
        // If spark not available, use a tiny rect
        let sz = CGSize(width: 3, height: 12)
        UIGraphicsBeginImageContextWithOptions(sz, false, 0)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 1).fill()
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            emitter.particleTexture = SKTexture(image: img)
        }
        UIGraphicsEndImageContext()

        return emitter
    }

    // MARK: - Snow

    static func makeSnow(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(10, 150, t: intensity)
        emitter.particleLifetime = 4.0
        emitter.particleLifetimeRange = 1.5

        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.5, 1.0, t: intensity)
        emitter.particleScale = lerp(0.08, 0.15, t: intensity)
        emitter.particleScaleRange = 0.04

        // Gentle drift down
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.6
        emitter.particleSpeed = lerp(40, 120, t: intensity)
        emitter.particleSpeedRange = 30

        // Horizontal wobble
        emitter.xAcceleration = 0
        // Will be updated per-frame for wind effect at high intensity

        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 50)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width * 1.2, dy: 0)

        // Small circle for snowflake
        let sz = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(sz, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: sz)).fill()
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            emitter.particleTexture = SKTexture(image: img)
        }
        UIGraphicsEndImageContext()

        return emitter
    }

    // MARK: - Sun Rays (visible at high sunny intensity)

    static func makeSunRays(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(0, 15, t: max(0, intensity - 0.3) / 0.7)
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5

        emitter.particleColor = UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 0.3)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.0, 0.4, t: intensity)
        emitter.particleAlphaSpeed = -0.15
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3

        // Radiate from top-right corner
        emitter.position = CGPoint(x: sceneSize.width * 0.35, y: sceneSize.height * 0.4)
        emitter.emissionAngle = -.pi * 0.6
        emitter.emissionAngleRange = .pi * 0.4
        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 20

        // Elongated ray shape
        let sz = CGSize(width: 4, height: 40)
        UIGraphicsBeginImageContextWithOptions(sz, false, 0)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 2).fill()
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            emitter.particleTexture = SKTexture(image: img)
        }
        UIGraphicsEndImageContext()

        return emitter
    }

    // MARK: - Helpers

    private static func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t.clamped(0, 1)
    }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(self, lo), hi)
    }
}
```

**Step 2: Wire particles into WeatherScene**

Add to `WeatherScene.swift` — a `currentEmitter` property, create/replace emitter when weather type changes, update `particleBirthRate` each frame based on intensity.

In `WeatherScene`, add:
- Property: `private var currentEmitter: SKEmitterNode?`
- In `update(_:)`: when weather changes, remove old emitter, create new one via `ParticleFactory`. Each frame, update emitter birth rate with `ParticleFactory` lerp logic.

```swift
// Add to WeatherScene properties:
private var currentEmitter: SKEmitterNode?

// Add to update(_:) after the weather type change block:
// Update particles
if currentEmitter == nil || weather != currentWeatherType {
    currentEmitter?.removeFromParent()
    currentEmitter = nil

    switch weather {
    case .rainy:
        let e = ParticleFactory.makeRain(sceneSize: size, intensity: intensity)
        particleLayer.addChild(e)
        currentEmitter = e
    case .snowy:
        let e = ParticleFactory.makeSnow(sceneSize: size, intensity: intensity)
        particleLayer.addChild(e)
        currentEmitter = e
    case .sunny:
        let e = ParticleFactory.makeSunRays(sceneSize: size, intensity: intensity)
        particleLayer.addChild(e)
        currentEmitter = e
    case .cloudy:
        break // no particles, just tint
    }
}

// Update existing emitter intensity
if let emitter = currentEmitter {
    switch weather {
    case .rainy:
        emitter.particleBirthRate = ParticleFactory.lerp(20, 300, t: intensity)
    case .snowy:
        emitter.particleBirthRate = ParticleFactory.lerp(10, 150, t: intensity)
        emitter.xAcceleration = intensity > 0.8 ? 30 : 0 // wind at peak
    case .sunny:
        emitter.particleBirthRate = ParticleFactory.lerp(0, 15, t: max(0, intensity - 0.3) / 0.7)
    case .cloudy:
        break
    }
}
```

**Note:** The `lerp` helper in `ParticleFactory` needs to be made `static` (not `private static`) so `WeatherScene` can call it, OR move the birth-rate update logic into a `ParticleFactory.updateIntensity(emitter:weather:intensity:)` method.

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/ParticleFactory.swift Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
git commit -m "feat(weather): add ParticleFactory — rain, snow, sun rays with intensity scaling"
```

---

### Task 5: CharacterAnimator — Sprite Sheet Flipbook & Movement

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/CharacterAnimator.swift`
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift`

**Step 1: Create CharacterAnimator.swift**

```swift
// Packages/WeatherFun/Sources/WeatherFun/CharacterAnimator.swift
import SpriteKit

class CharacterAnimator {

    // MARK: - State
    private var isAnimating = false
    private var lastTriggerTime: TimeInterval = 0
    private weak var characterLayer: SKNode?
    private var sceneSize: CGSize = .zero

    init(characterLayer: SKNode) {
        self.characterLayer = characterLayer
    }

    // MARK: - Update

    func update(currentTime: TimeInterval, weather: WeatherType, intensity: CGFloat, sceneSize: CGSize) {
        self.sceneSize = sceneSize

        guard intensity >= IntensityThreshold.characterTrigger,
              !isAnimating,
              currentTime - lastTriggerTime >= CharacterConfig.config(for: weather).cooldown else {
            return
        }

        triggerCharacter(weather: weather, currentTime: currentTime)
    }

    // MARK: - Trigger

    private func triggerCharacter(weather: WeatherType, currentTime: TimeInterval) {
        guard let layer = characterLayer else { return }
        isAnimating = true
        lastTriggerTime = currentTime

        let config = CharacterConfig.config(for: weather)
        let sprite: SKSpriteNode

        // Try to load sprite sheet from bundle
        if let textures = loadSpriteSheet(named: config.spriteSheet, frameCount: config.frameCount) {
            sprite = SKSpriteNode(texture: textures.first)
            let animate = SKAction.animate(with: textures, timePerFrame: config.timePerFrame)
            sprite.run(SKAction.repeatForever(animate))
        } else {
            // Fallback: colored circle placeholder
            sprite = makePlaceholderSprite(for: weather)
        }

        // Start offscreen left, move to offscreen right
        let startX = -sceneSize.width / 2 - 80
        let endX = sceneSize.width / 2 + 80
        let groundY = -sceneSize.height * 0.3 // roughly ground level

        sprite.position = CGPoint(x: startX, y: groundY)
        sprite.setScale(0.5)
        sprite.zPosition = 5
        layer.addChild(sprite)

        let move = SKAction.moveTo(x: endX, duration: config.crossDuration)
        move.timingMode = .easeInEaseOut

        sprite.run(SKAction.sequence([
            move,
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                self?.isAnimating = false
            }
        ]))
    }

    // MARK: - Sprite Sheet Loading

    private func loadSpriteSheet(named name: String, frameCount: Int) -> [SKTexture]? {
        // Attempt to load from bundle as a horizontal strip
        guard let image = UIImage(named: name, in: Bundle.module, compatibleWith: nil) else {
            return nil
        }
        let texture = SKTexture(image: image)
        let frameWidth = 1.0 / CGFloat(frameCount)
        var textures: [SKTexture] = []
        for i in 0..<frameCount {
            let rect = CGRect(x: CGFloat(i) * frameWidth, y: 0, width: frameWidth, height: 1.0)
            textures.append(SKTexture(rect: rect, in: texture))
        }
        return textures
    }

    // MARK: - Placeholder

    private func makePlaceholderSprite(for weather: WeatherType) -> SKSpriteNode {
        let colors: [WeatherType: UIColor] = [
            .sunny: .yellow,
            .cloudy: .gray,
            .rainy: .blue,
            .snowy: .white
        ]
        let emoji: [WeatherType: String] = [
            .sunny: "😎",
            .cloudy: "🌂",
            .rainy: "🌧️",
            .snowy: "⛄"
        ]

        // Create a labeled circle as placeholder
        let size = CGSize(width: 80, height: 80)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor((colors[weather] ?? .gray).cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))

        let str = emoji[weather] ?? "?"
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40)]
        let strSize = (str as NSString).size(withAttributes: attrs)
        (str as NSString).draw(at: CGPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2), withAttributes: attrs)

        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return SKSpriteNode(texture: SKTexture(image: img))
    }
}
```

**Step 2: Wire into WeatherScene**

Add to `WeatherScene`:
- Property: `private var characterAnimator: CharacterAnimator!`
- In `didMove(to:)` after creating `characterLayer`: `characterAnimator = CharacterAnimator(characterLayer: characterLayer)`
- In `update(_:)`: `characterAnimator.update(currentTime: currentTime, weather: weather, intensity: intensity, sceneSize: size)`

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/CharacterAnimator.swift Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
git commit -m "feat(weather): add CharacterAnimator — sprite sheet flipbook, placeholder fallback"
```

---

### Task 6: WeatherView — SpriteView Wrapper, Touch Overlay, Settings Sheet

**Files:**
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift`

**Step 1: Replace placeholder WeatherView with full implementation**

```swift
// Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
import SwiftUI
import SpriteKit

public struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WeatherViewModel()
    @State private var showSettings = false
    @State private var settingsTapCount = 0

    public init() {}

    public var body: some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: makeScene(), options: [.allowsTransparency])
                .ignoresSafeArea()

            // Invisible touch overlay — captures scribbling
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            viewModel.isTouching = true
                        }
                        .onEnded { _ in
                            viewModel.isTouching = false
                        }
                )

            // HUD overlay
            VStack {
                HStack {
                    // Home button
                    Button {
                        dismiss()
                    } label: {
                        Text("🏠")
                            .font(.system(size: 36))
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.7)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)

                    Spacer()

                    // Settings gear — triple tap
                    Text("⚙️")
                        .font(.system(size: 24))
                        .padding(10)
                        .background(Circle().fill(.white.opacity(0.3)))
                        .onTapGesture(count: 3) {
                            showSettings = true
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
                Spacer()
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
        }
    }

    private func makeScene() -> WeatherScene {
        let scene = WeatherScene()
        scene.viewModel = viewModel
        scene.size = UIScreen.main.bounds.size
        scene.scaleMode = .resizeFill
        return scene
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingZip: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Weather Location")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Zip Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Enter zip code", text: $editingZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 22, design: .rounded))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4)))

                    if let error = viewModel.zipError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    viewModel.zipCode = editingZip
                    viewModel.fetchWeather()
                    if viewModel.zipError == nil {
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color(r: 80, g: 160, b: 255)))
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { editingZip = viewModel.zipCode }
    }
}

// MARK: - iOS 15/16 Sheet Helpers

private extension View {
    @ViewBuilder
    func weatherSheetDetents() -> some View {
        if #available(iOS 16, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }

    @ViewBuilder
    func weatherDragIndicator() -> some View {
        if #available(iOS 16, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

// MARK: - Private Extensions

private extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1
        )
    }
}
```

**Step 2: Verify build + test on simulator**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild ... build 2>&1 | grep -E '(error:|BUILD)'"
```

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
git commit -m "feat(weather): complete WeatherView — SpriteView wrapper, touch overlay, settings"
```

---

### Task 7: Audio Manager — Ambient Loops & Character Sound Effects

**Files:**
- Create: `Packages/WeatherFun/Sources/WeatherFun/WeatherAudioManager.swift`
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift` (call audio updates)
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift` (init audio on appear)

**Step 1: Create WeatherAudioManager.swift**

```swift
// Packages/WeatherFun/Sources/WeatherFun/WeatherAudioManager.swift
import AVFoundation

class WeatherAudioManager {
    // MARK: - Players
    private var ambientPlayer: AVAudioPlayer?
    private var fadingOutPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?

    // MARK: - State
    private var currentWeatherType: WeatherType?
    private var crossfadeTimer: Timer?

    // MARK: - Init
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Update (called per frame or on change)

    func update(weather: WeatherType, intensity: CGFloat) {
        // Switch ambient loop if weather changed
        if weather != currentWeatherType {
            switchAmbient(to: weather)
            currentWeatherType = weather
        }

        // Scale volume with intensity
        let config = AudioConfig.config(for: weather)
        let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(intensity)
        ambientPlayer?.volume = volume
    }

    // MARK: - Character SFX

    func playCharacterSound(for weather: WeatherType) {
        let config = AudioConfig.config(for: weather)
        guard let file = config.characterSoundFile,
              let ext = config.characterSoundExtension,
              let url = Bundle.module.url(forResource: file, withExtension: ext) else {
            return
        }
        sfxPlayer = try? AVAudioPlayer(contentsOf: url)
        sfxPlayer?.volume = 0.8
        sfxPlayer?.play()
    }

    // MARK: - Ambient Crossfade

    private func switchAmbient(to weather: WeatherType) {
        let config = AudioConfig.config(for: weather)
        guard let url = Bundle.module.url(forResource: config.ambientFile, withExtension: config.ambientExtension) else {
            ambientPlayer?.stop()
            ambientPlayer = nil
            return
        }

        // Fade out old
        if let old = ambientPlayer {
            fadingOutPlayer = old
            crossfadeTimer?.invalidate()
            let fadeSteps = 30
            var step = 0
            crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                step += 1
                let progress = Float(step) / Float(fadeSteps)
                self?.fadingOutPlayer?.volume *= (1.0 - progress * 0.1)
                if step >= fadeSteps {
                    timer.invalidate()
                    self?.fadingOutPlayer?.stop()
                    self?.fadingOutPlayer = nil
                }
            }
        }

        // Start new
        ambientPlayer = try? AVAudioPlayer(contentsOf: url)
        ambientPlayer?.numberOfLoops = -1
        ambientPlayer?.volume = config.minVolume
        ambientPlayer?.play()
    }

    // MARK: - Cleanup

    func stop() {
        crossfadeTimer?.invalidate()
        ambientPlayer?.stop()
        fadingOutPlayer?.stop()
        sfxPlayer?.stop()
    }
}
```

**Step 2: Wire into WeatherScene and CharacterAnimator**

- Add `var audioManager: WeatherAudioManager?` to `WeatherScene`
- In `WeatherScene.update(_:)`: call `audioManager?.update(weather: weather, intensity: intensity)`
- In `CharacterAnimator.triggerCharacter()`: call `audioManager?.playCharacterSound(for: weather)`
  (pass `audioManager` reference into `CharacterAnimator` init)
- In `WeatherView.makeScene()`: `scene.audioManager = WeatherAudioManager()`

**Step 3: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherAudioManager.swift Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
git commit -m "feat(weather): add WeatherAudioManager — ambient loops, crossfade, character SFX"
```

---

### Task 8: Hub Layout — 2x2 + Centered Bottom Row

**Files:**
- Modify: `ColoringApp/HubView.swift`
- Modify: `ColoringApp/AppRegistry.swift`

**Step 1: Update HubView to support overflow row**

In `HubView.swift`, replace the `LazyVGrid` section with logic that splits apps into grid rows and an overflow centered row:

```swift
// Replace the LazyVGrid block with:
let gridApps = Array(AppRegistry.apps.prefix(4))
let overflowApps = Array(AppRegistry.apps.dropFirst(4))

LazyVGrid(columns: columns, spacing: 24) {
    ForEach(gridApps) { app in
        AppTileView(app: app) {
            if app.isAvailable {
                activeApp = app
            } else {
                requestingApp = app
            }
        }
    }
}
.padding(.horizontal, 48)

if !overflowApps.isEmpty {
    HStack(spacing: 24) {
        ForEach(overflowApps) { app in
            AppTileView(app: app) {
                if app.isAvailable {
                    activeApp = app
                } else {
                    requestingApp = app
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width / 2 - 60)
        }
    }
    .padding(.horizontal, 48)
}
```

**Step 2: Add WeatherFun entry to AppRegistry.swift** (already done in Task 0)

Verify the import and entry are present.

**Step 3: Verify layout on simulator**

Build and check that the 5th tile appears centered below the 2x2 grid.

**Step 4: Commit**

```bash
git add ColoringApp/HubView.swift
git commit -m "feat(hub): support overflow row for 5+ apps, centered bottom tile"
```

---

### Task 9: Generate & Bundle Placeholder Assets

**Files:**
- Add: `Packages/WeatherFun/Sources/WeatherFun/Resources/` (image + audio files)

This task is partially manual — it requires running DALL-E 3 prompts and downloading sound files.

**Step 1: Generate background image via DALL-E 3**

Use this prompt:
```
A simple children's book illustration of a cozy neighborhood street, front view. A small house with a red door and white picket fence, a green tree, a sidewalk with a fire hydrant, and a grassy yard. Flat colors, soft pastels, rounded shapes, no outlines, digital illustration style similar to Peppa Pig or Hey Duggee. Daytime with a light blue sky. No people or animals. Wide landscape aspect ratio, suitable as a game background layer.
```

Save as `neighborhood_base.png` (2048x1536 or crop to fit). Place in `Resources/`.

**Step 2: Generate character sprite sheets** (one per weather type)

Run 4 prompts for sunny/cloudy/rainy/snowy character variants. Save as horizontal strip PNGs in `Resources/`.

If DALL-E doesn't produce clean sprite sheets, use placeholders for now — the `CharacterAnimator` fallback (emoji circles) will work.

**Step 3: Download sound assets**

From Pixabay + Freesound CC0:
- `ambient_sunny.m4a` — birds chirping loop
- `ambient_cloudy.m4a` — light wind loop
- `ambient_rainy.m4a` — rain patter loop
- `ambient_snowy.m4a` — muffled winter wind loop
- `sfx_giggle.caf` — child giggle
- `sfx_wind_gust.caf` — comedic wind sound
- `sfx_splash.caf` — puddle splash
- `sfx_snow_crunch.caf` — snow footstep crunch

Convert to correct formats:
```bash
# On Mac — convert downloaded files
afconvert input.wav output.m4a -d aac -f m4af  # for ambient loops
afconvert input.wav output.caf -d LEI16 -f caff  # for one-shots
```

Place all in `Packages/WeatherFun/Sources/WeatherFun/Resources/`.

**Step 4: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/Resources/
git commit -m "feat(weather): add placeholder image and sound assets"
```

---

### Task 10: WeatherKit Entitlement (Mac-side)

**Must be done on Mac in Xcode GUI — cannot be done from WSL.**

**Step 1: Open project in Xcode**

On Mac, open `ColoringFun.xcodeproj`.

**Step 2: Add WeatherKit capability**

1. Select the `ColoringFun` target
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Search for "WeatherKit" and add it
5. This adds the `com.apple.developer.weatherkit` entitlement

**Step 3: Build to verify**

```bash
xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'
```

**Step 4: Commit on Mac**

```bash
git add -A && git commit -m "chore: add WeatherKit entitlement"
```

**Step 5: Patch to WSL**

```bash
ssh claude@192.168.50.251 "git -C ~/Dev/coloringApp format-patch HEAD~1 --stdout" > /tmp/patch.patch
git am /tmp/patch.patch && git push
```

---

### Task 11: Ground Effects — Puddles, Snow Accumulation, Heat Shimmer

**Files:**
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift`

**Step 1: Add ground effect nodes to WeatherScene**

In `WeatherScene`, add methods to show/hide ground effects based on weather + intensity:

- **Rainy (intensity > 0.3):** Add 2-3 `SKSpriteNode` puddles at ground level, fade in with intensity. If `puddle_overlay.png` exists in bundle, use it; otherwise generate programmatic blue oval sprites.
- **Snowy (intensity > 0.3):** Add `snow_ground_overlay.png` (or white rectangle) at bottom, opacity scales with intensity.
- **Sunny (intensity > 0.8):** Subtle heat shimmer — a semi-transparent wavy sprite node with a `SKAction` that oscillates its position slightly.

Manage via `groundEffectsNode` container. Clear and rebuild when weather type changes.

**Step 2: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
git commit -m "feat(weather): add ground effects — puddles, snow buildup, heat shimmer"
```

---

### Task 12: Lightning Flash (Rainy Peak Effect)

**Files:**
- Modify: `Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift`

**Step 1: Add lightning flash at peak rainy intensity**

When rainy + intensity > 0.8, periodically flash a white overlay:

```swift
// In update(_:), when rainy and intensity > peakEffects:
private var lastFlashTime: TimeInterval = 0

// In update:
if weather == .rainy && intensity > IntensityThreshold.peakEffects {
    if currentTime - lastFlashTime > 4.0 + Double.random(in: 0...3) {
        lastFlashTime = currentTime
        let flash = SKSpriteNode(color: .white, size: size)
        flash.zPosition = 60
        flash.alpha = 0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.05),
            SKAction.fadeAlpha(to: 0, duration: 0.3),
            SKAction.removeFromParent()
        ]))
    }
}
```

This is a bright white flash — playful, not scary. No thunder sound.

**Step 2: Commit**

```bash
git add Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
git commit -m "feat(weather): add lightning flash effect at peak rain intensity"
```

---

### Task 13: Final Integration Build & Smoke Test

**Step 1: Build on Mac**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

**Step 2: Manual smoke test on simulator**

- Launch app → Hub shows 5 tiles (4 in grid + Weather Fun centered below)
- Tap Weather Fun → scene loads with sky + background (or placeholder)
- Drag finger anywhere → intensity builds, particles appear (if rainy/snowy weather)
- Stop dragging → intensity slowly decays
- Triple-tap gear → settings sheet opens, zip code field visible
- Home button → returns to hub

**Step 3: Fix any build errors or layout issues**

Iterate until clean.

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(weather): Weather Fun complete — SpriteKit scene, WeatherKit, audio, hub integration"
```
