# Weather Fun — Design Document

## Overview

A weather app for toddlers. Opens to a neighborhood scene showing the real weather for a parent-configured zip code. The toddler scribbles anywhere on screen (no visible marks) to slowly intensify the weather over 10-15 seconds. When intensity gets high enough, an animated character runs across the screen with weather-appropriate actions. When the toddler stops scribbling, the weather gradually fades back over ~30 seconds.

**Teaching concept:** Weather does not change on a dime — it changes over hours. The slow ramp-up and gradual decay reinforces cause-and-effect while teaching that weather is a gradual process.

## Architecture

**SpriteKit + SwiftUI hybrid** in a Swift package (`Packages/WeatherFun/`).

- SpriteKit handles the animated scene: background, sky, weather particles, character animations
- SwiftUI handles navigation (Home button), touch input overlay, and parent settings sheet
- `SpriteView` bridges the two — SwiftUI wraps the SKScene

### Package Structure

```
Packages/WeatherFun/
├── Package.swift
└── Sources/WeatherFun/
    ├── WeatherView.swift          — Public entry point (SwiftUI), SpriteView wrapper, touch overlay, settings sheet
    ├── WeatherViewModel.swift     — WeatherKit fetch, zip geocoding, intensity state + decay, weather type mapping
    ├── WeatherScene.swift         — SKScene subclass: background, sky gradient, layer composition, intensity updates
    ├── ParticleFactory.swift      — Creates configured SKEmitterNodes per weather type
    ├── CharacterAnimator.swift    — Sprite sheet loading, flipbook SKActions, movement paths, trigger logic
    ├── WeatherModels.swift        — WeatherType enum, thresholds, condition mapping, audio config
    └── Resources/                 — Bundled image + audio assets
```

### Data Flow

1. `WeatherView` (SwiftUI) owns `@StateObject var viewModel: WeatherViewModel`
2. ViewModel fetches weather via WeatherKit on appear, stores current `WeatherType`
3. SwiftUI transparent overlay captures DragGesture → feeds scribble energy to viewModel → viewModel updates `intensity: CGFloat` (0.0–1.0) with 10-15s ramp and ~30s decay
4. `WeatherScene` (SpriteKit) observes the viewModel and updates particles, sky tint, character triggers based on `weatherType` + `intensity`

## Weather Types

Four types mapped from WeatherKit's ~30 conditions:

| WeatherType | Apple conditions mapped |
|---|---|
| `.sunny` | clear, mostlyClear, hot |
| `.cloudy` | cloudy, mostlyCloudy, partlyCloudy, foggy, haze, smoky |
| `.rainy` | rain, heavyRain, drizzle, thunderstorms, tropicalStorm |
| `.snowy` | snow, heavySnow, sleet, freezingRain, freezingDrizzle, blizzard, flurries |

## Scene Rendering

### Layers (back to front, SpriteKit z-order)

1. **Sky background** — Gradient node, color shifts with weather type + intensity
2. **DALL-E neighborhood image** — Static sprite, color-tinted via `colorBlendFactor`
3. **Weather particles** — `SKEmitterNode` for rain/snow; particle count scales with intensity
4. **Ground effects** — Puddles (rainy), snow buildup (snowy), heat shimmer (sunny high intensity)
5. **Character layer** — Animated toddler sprite, triggered at ~0.6 intensity

### Intensity Effects

| Intensity | 0.0 (baseline) | 0.5 (moderate) | 1.0 (max) |
|---|---|---|---|
| Sunny | Normal daylight | Brighter, warm tint | Golden glow, sun rays, lens flare |
| Cloudy | Light overcast | Grayer, more clouds | Dark and moody, clouds cover sky |
| Rainy | Light drizzle | Steady rain, puddles appear | Downpour, puddles grow, lightning flash |
| Snowy | Light flurries | Steady snow, ground whitens | Blizzard, heavy accumulation, wind drift |

### Character Animations (triggered at ~0.6 intensity)

| Weather | Character | Action | Sound |
|---|---|---|---|
| Sunny | Kid with sunglasses | Skips across screen, shields eyes | Giggle + birds louder |
| Cloudy | Kid with umbrella | Walks slowly, looks up | Footsteps + wind gust |
| Rainy | Kid in rain boots | Runs across, splashes puddles | Splash sounds cascading L→R |
| Snowy | Kid in snow gear | Waddles across, tosses snowball | Snow crunch + giggle + poof |

Characters enter from one side, cross screen over ~3 seconds, exit. Re-trigger after ~10s cooldown if intensity stays high.

## Touch Input & Intensity Mechanics

- Transparent SwiftUI overlay captures `DragGesture` — any finger movement counts as scribbling
- No visible crayon marks — touch is invisible, only weather responds
- Single touch (no multi-touch needed for a 3-year-old)

**Ramp:** `intensity += 0.005` per frame (~60fps) → 0→1.0 in ~13 seconds of continuous scribbling. Erratic lifting/replanting still accumulates.

**Decay:** `intensity -= 0.002` per frame → 1.0→0.0 in ~33 seconds. Slower than ramp so the toddler sees results linger.

**Thresholds:**

| Threshold | Event |
|---|---|
| 0.0–0.3 | Baseline weather, subtle ambient sounds |
| 0.3 | Ground effects begin (puddles, snow dusting, heat waves) |
| 0.5 | Ambient sound volume increase, particle density ramps |
| 0.6 | Character animation triggers |
| 0.8 | Peak visual effects (lightning flashes, blizzard wind) |
| 1.0 | Maximum intensity — dramatic but not scary |

**UX note:** Nothing should be frightening. Lightning is a bright white flash (no dark thunder), rain is playful not ominous, max intensity should feel exciting and silly, not overwhelming.

## Audio System

### Ambient Loops (one per weather type, volume scales with intensity)

| Weather | Sound | Volume range |
|---|---|---|
| Sunny | Birds chirping, gentle breeze | 0.1 → 0.7 |
| Cloudy | Light wind, distant rustling | 0.1 → 0.5 |
| Rainy | Rain patter on roof/ground | 0.1 → 0.8 |
| Snowy | Muffled quiet, soft wind | 0.05 → 0.4 |

### Character Sound Effects (one-shot, triggered with animation)

| Weather | Sound |
|---|---|
| Sunny | Child giggle |
| Cloudy | Footsteps + comedic wind gust |
| Rainy | Splash-splash-splash cascading L→R |
| Snowy | Snow crunch + giggle + soft poof |

### Implementation

- `AVAudioPlayer` with `AVAudioSession(.playback)` (same pattern as StampSynth)
- Ambient loops: `.m4a` format, `numberOfLoops = -1`
- One-shot effects: `.caf` format for low latency
- Crossfade ambient loops over ~3 seconds when weather type changes
- Character exclamations via `AVSpeechSynthesizer` (consistent with SpellingFun/TraceFun)

### Sound Sources

All sounds sourced from no-attribution-required licenses:
- **Pixabay** (Pixabay license — royalty-free, no attribution): rain loops, gentle/distant thunder, child giggles, winter ambient, snow crunch
- **Freesound CC0** (public domain): puddle splash (launemax), birds loop (Magnesus), gentle breeze (mario1298), snow footsteps (florianreichelt)

## Zip Code Configuration & WeatherKit Integration

### Parent Settings

- Triple-tap gear icon in corner → settings sheet
- Single field: zip code, numeric keyboard
- Default: `"10001"` (NYC), stored in `UserDefaults["weatherZipCode"]`
- Validates 5 digits, inline error for invalid input
- Save dismisses sheet, triggers fresh weather fetch
- Uses `kidSheetDetents()` / `kidDragIndicator()` for iOS 15 compat

### WeatherKit Flow

```
Zip code → CLGeocoder (zip → coordinate) → WeatherKit.WeatherService → WeatherCondition → WeatherType
```

1. `CLGeocoder().geocodeAddressString(zipCode)` — no location permission needed
2. `WeatherService.shared.weather(for: location, including: .current)`
3. Map condition → `WeatherType` enum
4. Cache result, refresh every 30 minutes (well within WeatherKit free tier)

### iOS 15 Fallback

```swift
if #available(iOS 16, *) {
    // WeatherKit fetch
} else {
    // Random weather type, rotates daily based on date hash
}
```

### Error Handling

- Network unavailable → last cached weather, or random if no cache
- Invalid zip → inline error in settings sheet, keep previous zip
- WeatherKit fetch fails → same as network unavailable
- No error states visible to the toddler — only parent sees errors in settings

## Asset Pipeline

### DALL-E 3 Generated Images (one-time, during development)

| Asset | Dimensions | Description |
|---|---|---|
| `neighborhood_base.png` | 2048x1536 | Neighborhood scene — house, yard, fence, tree, sidewalk. Clear sky area for SpriteKit tinting |
| `character_sunny_sheet.png` | 512x128 (4 frames) | Kid with sunglasses, skipping poses |
| `character_cloudy_sheet.png` | 512x128 (4 frames) | Kid with umbrella, walking poses |
| `character_rainy_sheet.png` | 512x128 (4 frames) | Kid in rain boots, running/splashing |
| `character_snowy_sheet.png` | 512x128 (4 frames) | Kid in snow gear, waddling/throwing |
| `puddle_overlay.png` | 256x64 | Puddle sprite for ground layer |
| `snow_ground_overlay.png` | 2048x256 | Snow accumulation strip |

### Audio Assets (~2-3MB total)

- Ambient loops: `.m4a` (compressed)
- One-shot effects: `.caf` (uncompressed, low latency)
- Bundled via SPM `resources: [.process("Resources")]`

### Estimated Bundle Size Impact: ~3-4MB

## Hub Integration

### Layout Change (2x2 → 2x2 + centered bottom)

```
┌─────────────┐ ┌─────────────┐
│  🎨 Coloring │ │  🌈 Kids    │
│     Fun      │ │    Mode     │
└─────────────┘ └─────────────┘
┌─────────────┐ ┌─────────────┐
│  ✏️ Spelling │ │  🖍️ Trace   │
│     Fun      │ │    Fun      │
└─────────────┘ └─────────────┘
       ┌─────────────┐
       │  🌤️ Weather  │
       │     Fun      │
       └─────────────┘
```

- `LazyVGrid` for first 4 tiles, centered `HStack` for 5th tile below
- Naturally extends to more tiles if apps are added later

### App Registration

```swift
import WeatherFun
// ...
MiniAppDescriptor(
    id: "weather",
    displayName: "Weather Fun",
    subtitle: "Paint the Weather!",
    icon: "🌤️",
    tileColor: Color(r: 180, g: 220, b: 255),
    isAvailable: true,
    makeRootView: { AnyView(WeatherView()) }
)
```

### Project Setup (Mac-side)

- `project.pbxproj` registration via Python script (UUIDs: `E1E2E3E4E5E6E7E8E9F0F1F2` / `F1F2F3F4F5F6F7F8F9A0A1A2`)
- WeatherKit entitlement: `com.apple.developer.weatherkit` added in Xcode capabilities

## Out of Scope (YAGNI)

- No forecast / multi-day view
- No night mode — always daytime
- No weather type switching by toddler — crayon only intensifies
- No saving or persistence — each session starts fresh
- No portrait mode — landscape only
- No wind as separate weather type — folded into cloudy/snowy
