## ⚡ SESSION RESUME
At the start of this session, read `docs/plans/2026-02-27-weather-fun.md`, tell the user
you're ready to continue from Task 0 (Create Package Skeleton & Verify Build), then wait for their go-ahead.

# Coloring App — Project Memory

## Project Overview
iPad SwiftUI coloring app for 3-year-olds.
GitHub: https://github.com/xgeetex/coloringApp

**Paths:**
- macOS (build machine): `/Users/claude/Dev/coloringApp/` (SSH: `claude@192.168.50.251`)
- WSL (editing machine): `/home/geet/Claude/coloringApp/`

**Workflow:** Edit in WSL → commit + push → SSH to Mac for `git pull` + `xcodebuild`.

**Build command (simulator):**
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Deploy to iPad:** Must use Terminal on Mac **as `garrettshannon`** — `claude` SSH keychain locks during SSH sessions (`errSecInternalComponent` at CodeSign). Command: `xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'id=28b1b65d4528209892b1ef4389dee775a537648b' build`. iPad UDID: `28b1b65d4528209892b1ef4389dee775a537648b`.

Xcode project: `ColoringFun.xcodeproj` (iPad-only, iOS 15+, bundle ID `com.coloringapp.ColoringFun`, team `T2DJZ649J4`).

## File Structure
```
coloringApp/
├── ColoringFun.xcodeproj/
├── ColoringApp/                    — main target
│   ├── ColoringApp.swift           — @main; root is HubView()
│   ├── AppRegistry.swift           — MiniAppDescriptor + AppRegistry.apps; imports SpellingFun + TraceFun + WeatherFun
│   ├── HubView.swift               — 2×2 grid launcher, triple-tap title to rename
│   ├── AppRequestView.swift        — voice dictation → email app request flow
│   ├── ContentView.swift           — parent-mode root: activeFlyout + strip/canvas/flyout layout
│   ├── Models.swift                — DrawingElement, DrawingState, Stroke, StampPlacement, FlyoutPanel, BrushDescriptor, CrayolaColor (20 colors), allStampCategories (5 categories)
│   ├── DrawingPersistence.swift    — Codable wrappers + CodableDrawingElement; backward-compat DrawingSnapshot
│   ├── DrawingCanvasView.swift     — Canvas rendering; crayon grain-texture + marker bleed/transparency for user brushes; unified z-order; eraser hit-tests stamps; pinch shows size indicator
│   ├── ColorPaletteView.swift      — ColorPicker pinned left + 20 Crayola swatches in horizontal ScrollView
│   ├── ToolsView.swift             — BrushesFlyoutView, SizeFlyoutView, OpacityFlyoutView, PoolPickerView
│   ├── StampsView.swift            — StampsFlyoutView(isKidMode:Bool=false), StampButton(fontSize:), kidCategoryColors (5 pastel tabs)
│   ├── TopToolbarView.swift        — Home, Title, BG color picker, Undo, Clear, Eraser toggle, Stamps layer toggle
│   ├── FlyoutContainerView.swift   — Generic flyout wrapper: slide animation, X button, shadow
│   ├── LeftStripView.swift         — 44pt icon strip (brush/size/opacity)
│   ├── RightStripView.swift        — 44pt icon strip (stamps only)
│   ├── BrushBuilderView.swift      — Full brush builder; opens as .sheet
│   ├── KidContentView.swift        — Kid-mode root + KidBrushPreview + KidBrushStripView + KidStampGridView (2 per cat, 44pt) + KidStampTile + StampSynth (AVAudioSession) + stampSoundMap
│   ├── KidBrushBuilderView.swift   — Kid texture designer: crayon=grain slider, marker=bleed+transparency, chalk=bold+grain-spread, glitter=dense/spread
│   └── Info.plist
├── Packages/                       — local Swift packages (NEVER touch project.pbxproj from WSL)
│   ├── SpellingFun/Sources/SpellingFun/SpellingView.swift
│   ├── TraceFun/Sources/TraceFun/LetterTraceView.swift
│   └── WeatherFun/Sources/WeatherFun/  — SpriteKit+SwiftUI weather app (planned, not yet built)
│       ├── WeatherView.swift       — public entry, SpriteView wrapper, touch overlay, settings
│       ├── WeatherViewModel.swift  — WeatherKit fetch, intensity ramp/decay, zip geocoding
│       ├── WeatherScene.swift      — SKScene: sky gradient, background, particles, characters
│       ├── ParticleFactory.swift   — programmatic SKEmitterNodes (rain, snow, sun rays)
│       ├── CharacterAnimator.swift — sprite sheet flipbook + cross-screen movement
│       ├── WeatherModels.swift     — WeatherType enum, thresholds, configs
│       └── Resources/              — DALL-E backgrounds, Pixabay/CC0 audio assets
└── docs/
    ├── feedback/
    │   ├── wife_feedback_02_24_2026.rtf  — text feedback (all 11 items addressed)
    │   └── wife_feedback_02_24_2026.caf  — voice recording (untranscribed)
    └── plans/
        ├── 2026-02-25-feedback-round-2-design.md  — executed ✅
        ├── 2026-02-25-kid-mode-ux-round3.md       — partially executed (crayon box selector reverted, pending redesign)
        ├── 2026-02-27-weather-fun-design.md       — approved design ✅
        └── 2026-02-27-weather-fun.md              — implementation plan, 14 tasks, pending execution
```

## Architecture & Key Design Decisions

### Navigation (Hub → App)
- `HubView` is app root (`ColoringApp.swift`)
- `fullScreenCover(item: $activeApp)` launches live apps; `@Environment(\.dismiss)` in each app provides 🏠 Home
- Placeholder tiles open a `sheet` with `AppRequestView`
- Hub title triple-tap to rename, persisted to `UserDefaults["hubTitle"]`

### AppRegistry
- `MiniAppDescriptor: Identifiable & Equatable` (Equatable is id-based — closures block synthesis)
- `makeRootView: () -> AnyView` — each tile declares its own root
- Current tiles: 🎨 Coloring Fun (`ContentView`), 🌈 Kids Mode (`KidContentView`), ✏️ Spelling Fun (`SpellingView`), 🖍️ Trace Fun (`LetterTraceView`), 🌤️ Weather Fun (`WeatherView` — planned)
- Add new app: one entry in `AppRegistry.apps`, no other changes

### Flyout Panel Architecture (ContentView — parent mode)
- `@State var activeFlyout: FlyoutPanel?` controls which panel is open (`nil` = all closed)
- `FlyoutPanel` enum in `Models.swift`: `.brushes`, `.size`, `.opacity`, `.stamps`
- Layout: `LeftStripView (44pt) | ZStack(canvas + flyout overlays) | RightStripView (44pt)`
- Strip background must be `.ultraThinMaterial` — `.white.opacity(0.75)` is invisible on pastel gradient
- `DrawingCanvasView` accepts `dismissFlyout: (() -> Void)?` — called when a new stroke begins

### Kid Mode Architecture
- Separate `KidContentView` with its own `@StateObject var state = DrawingState()` — independent drawings
- Left strip: texture brushes (Crayon, Marker, Chalk, Sparkle + user-created); `KidBrushStripView` — Make button at TOP of bordered box, then user brushes below
- Right panel: `KidStampGridView` — 5 categories × 2 stamps (44pt emoji, 120pt-wide panel) + "More" → `StampsFlyoutView(isKidMode: true)` sheet
- `KidBrushPreview` routes on `brush.baseStyle` for ALL brushes (system and user); only `.patternStamp` user brushes use splatter
- `KidBrushBuilderView`: crayon=grain texture slider (`stampSpacing`), marker=ink bleed (`stampSpacing`) + transparency (`sizeVariation`), chalk=bold (`sizeVariation`) + grain spread (`stampSpacing`), glitter=dense/spread (`stampSpacing`); caps user brushes at 2
- `StampSynth` + `stampSoundMap` in `KidContentView.swift` — shared with `StampsView.swift` (internal access); `StampSynth` configures `AVAudioSession(.playback)` for device audio
- `KidTopToolbarView` shows Size + Opacity sliders when `!isEraserMode` (visible in both brush and stamp modes)
- No flyouts in kid mode; large targets (68pt buttons)
- iOS 15 compat: `kidSheetDetents()` / `kidDragIndicator()` `@ViewBuilder` extensions for `presentationDetents`/`presentationDragIndicator`

### Stamps & Z-Axis
- `StampPlacement` has `opacity: Double` — baked from `brushOpacity` at placement time
- **Unified z-order**: `DrawingElement` enum (`.stroke`/`.stamp`) in `drawingElements` array — renders in creation order by default (newest on top)
- `stampsAlwaysOnTop` toggle: when true, all strokes render first then all stamps on top
- Toggle button in both `TopToolbarView` and `KidTopToolbarView` (teal, layers icon)
- `strokes` and `stamps` are computed properties filtering `drawingElements` — existing code (eraser hit-test, etc.) works unchanged
- Unified undo: single `elementHistory` stack replaces separate stroke/stamp history
- 5 stamp categories: Animals, Insects, Plants, Fun, Faces (😀 — 15 happy/silly + 1 sad)
- `StampsFlyoutView(isKidMode: true)` → 3-column grid, 48pt emoji, pastel category tabs (orange/green/pink/purple/yellow), TTS sound on tap
- Pinch gesture shows overlay: ghost stamp (stamp mode) or circle (brush mode)

### Drawing Engine
- `DrawingState` is `ObservableObject`; `@StateObject` in root view — fresh per session, loads from disk on init
- 8 system brushes (fixed UUIDs): Crayon, Marker, Sparkle, Chalk, Hearts, Dots, Flowers, Confetti
- `.crayon`: 5-pass offset strokes + grain stipple dots; user brushes: `stampSpacing` controls grain texture amount (0=smooth, 2=heavy), affects dot density + spread + opacity
- `.marker`: halo pre-pass + solid pass; user brushes: `stampSpacing` controls ink bleed (halo width 1.6x–3.2x, halo opacity 0.04–0.16), `sizeVariation` controls transparency (solid opacity 0.30–0.90)
- `.chalk`: pure particle cloud — 5 dots per point; spread = `brushSize * 0.6` for system, `brushSize * 0.6 * stampSpacing` for user brushes
- `.patternStamp`: evenly spaced shape stamps along drag path
- Eraser: `BrushDescriptor.eraser` (UUID all-zeros), `renderHardErase()` at opacity 1.0; also hit-tests stamps
- Pinch resizes brush (6–80pt); `isPinching` flag prevents stroke artifacts
- Undo: unified `elementHistory` stack (single array of `[DrawingElement]`)

### Spelling Fun — app3 (`Packages/SpellingFun`)
- Voice-only input (no text field) → letters scatter to stage → drag tiles to hear letters spoken
- `public struct SpellingView: View` + `public init() {}`; private `Color(r:g:b:)` + `Comparable.clamped(to:)` inlined

### Letter Trace Fun — app4 (`Packages/TraceFun`)
- Voice → confirm → keyboard slides in → letters pop staggered (0.4s each) → trace with rainbow paint → celebrate
- State machine: `.idle → .listening → .confirm(word) → .tracing(word, letterIndex) → .celebrate(word)` in `LetterTraceViewModel (@MainActor)`
- **Glyph extraction**: `CTFontGetGlyphsForCharacters` (NOT `CTFontGetGlyphWithName`), Y-flipped to SwiftUI coords
- **Even-odd fill**: `FillStyle(eoFill: true)` for all glyph fills/masks + `cgPath.contains(point, using: .evenOdd)` — required for letter counters (P, B, D, O holes)
- **Coverage-based completion**: outline sampled every 20pt → `outlinePoints: [CGPoint]`; drag within fixed pixel radius (28/20/14pt easy/med/tricky) marks checkpoint covered; completion at 50%/65%/80% coverage
- **Checkpoint dots**: Canvas draws dots at each outline sample point, gray when uncovered, rainbow when covered — visually shows tracing progress along the letter perimeter
- `.id(currentIndex)` on `TracingLetterView` forces fresh `@State` per letter (prevents stale glyph on letter change)
- `.clipped()` on tracing area prevents overflow into keyboard/tile row
- Letter font size: `min(w,h) * 0.75` (was 0.95 — needs margin for checkpoint dots)
- Compact keyboard: 32pt rows, 16pt font, intrinsic height (no fractional sizing)
- Difficulty settings: triple-tap gear icon → sheet with easy/medium/tricky
- `public struct LetterTraceView: View` + `public init() {}`; private `Color(r:g:b:)` inlined

### Weather Fun — app5 (`Packages/WeatherFun`) — planned, not yet built
- SpriteKit + SwiftUI hybrid: `SKScene` wrapped in `SpriteView`, SwiftUI touch overlay + settings
- Real weather via WeatherKit (iOS 16+) + `CLGeocoder` zip→coords (no location permission); iOS 15 fallback: random weather
- Toddler scribbles anywhere (no visible marks) → intensity ramps 0→1 in ~13s, decays 1→0 in ~33s
- Intensity drives: particle density (rain/snow), sky tint, ground effects (puddles/snow), character animations at 0.6 threshold
- Parent config: triple-tap gear → zip code entry (default NYC 10001), stored in UserDefaults
- DALL-E 3 generated background + character sprite sheets; Pixabay/Freesound CC0 audio assets
- `AVAudioPlayer` ambient loops (volume scales with intensity) + one-shot character SFX
- Full design: `docs/plans/2026-02-27-weather-fun-design.md`; implementation plan: `docs/plans/2026-02-27-weather-fun.md`

### Drawing Persistence
- Saved to `Documents/currentDrawing.json` (`.atomic` write)
- `DrawingSnapshot` encodes unified `elements: [CodableDrawingElement]`; decodes both new and legacy (separate `strokes`+`stamps`) formats
- Legacy backward compat: old snapshots decode as stamps-first then strokes (matches old render order)
- `CodableStroke.opacity` and `CodableStampPlacement.opacity` both use `decodeIfPresent ?? 1.0`
- `persist()` (UserDefaults: brushes, opacity) is `internal`

### Project Config
- iOS 15.0 deployment target; `arm64`; `DEVELOPMENT_TEAM = T2DJZ649J4` committed in pbxproj

## Known Gotchas
- `MiniAppDescriptor` needs explicit `Equatable` — closures block synthesis
- New main-target `.swift` files need ALL 4 pbxproj insertions: **PBXBuildFile**, **PBXFileReference**, **PBXGroup children**, **PBXSourcesBuildPhase**
- New mini-apps → use Swift Package Protocol below; never hand-edit pbxproj SPM sections
- SSH deploys to iPad fail as `claude` — use Terminal as `garrettshannon`
- `AVAudioSession` must be configured before `inputNode` access
- `AVSpeechSynthesizer` needs `AVAudioSession.setCategory(.playback)` to produce audio on device — simulator works without it
- `SFSpeechRecognizer` callbacks are off main thread — dispatch to main or use `@MainActor`
- `foregroundStyle` ternary needs explicit `Color.` types — Swift inference fails across `some ShapeStyle`
- `.onChange(of:)` use single-param form `{ newValue in }` — two-param `{ old, new in }` is iOS 17+ only
- `presentationDetents` / `presentationDragIndicator` are iOS 16+ — use `kidSheetDetents()` / `kidDragIndicator()` helpers
- `AVSpeechSynthesizer`: call `stopSpeaking(at: .immediate)` before each new utterance
- `BrushDescriptor.stampSpacing` and `.sizeVariation` are overloaded per brush type — meanings differ (see Drawing Engine section)
- Core Text glyph paths use even-odd fill rule — SwiftUI `Path.fill()` defaults to non-zero winding; must use `FillStyle(eoFill: true)` for letters with counters (P, B, D, O, etc.)
- `CTFontGetGlyphWithName` returns wrong glyphs for some letters (e.g. P) — always use `CTFontGetGlyphsForCharacters`
- Hit-test radii for touch targets: fontSize-based fractions become absurdly large at big font sizes; prefer fixed pixel values
- SwiftUI `@State` persists when view identity doesn't change — use `.id(value)` to force view recreation when switching between same-type content (e.g. different letters in a tracing game)

## Swift Package Protocol (for new mini-apps)

Each new mini-app lives in `Packages/XxxFun/`. The Mac step is **fully automated via SSH**.

### WSL steps
1. Create `Packages/XxxFun/Package.swift`:
```swift
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "XxxFun",
    platforms: [.iOS(.v15)],
    products: [.library(name: "XxxFun", targets: ["XxxFun"])],
    targets: [.target(name: "XxxFun")]
)
```
2. Create `Packages/XxxFun/Sources/XxxFun/XxxView.swift`:
   - `public struct XxxView: View` + `public init() {}`
   - Add at bottom (NOT exported from main target):
```swift
private extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }
}
```
3. Add `import XxxFun` to `AppRegistry.swift` + new `MiniAppDescriptor` entry
4. Commit + push. **Never touch project.pbxproj from WSL.**

### Mac SSH step
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
```
Then run the Python script below. Next available UUIDs:
- Package ref: `F1F2F3F4F5F6F7F8F9A0A1A3`
- Product dep: `A1B2C3D4E5F6A7B8C9D0E1F2`

**Used UUIDs (do not reuse):**
- `A1A2A3A4A5A6A7A8A9B0B1B2` — SpellingFun pkg ref
- `B1B2B3B4B5B6B7B8B9C0C1C2` — TraceFun pkg ref
- `C1C2C3C4C5C6C7C8C9D0D1D2` — SpellingFun product dep
- `D1D2D3D4D5D6D7D8D9E0E1E2` — TraceFun product dep
- `E1E2E3E4E5E6E7E8E9F0F1F2` — WeatherFun pkg ref (reserved)
- `F1F2F3F4F5F6F7F8F9A0A1A2` — WeatherFun product dep (reserved)

```python
# Run on Mac: python3 script.py from ~/Dev/coloringApp
PKG_NAME = "XxxFun"
PKG_PATH = "Packages/XxxFun"
PKG_UUID  = "E1E2E3E4E5E6E7E8E9F0F1F2"
PROD_UUID = "F1F2F3F4F5F6F7F8F9A0A1A2"

with open('ColoringFun.xcodeproj/project.pbxproj', 'r') as f:
    c = f.read()

new_pkg_ref = (f'\t\t{PKG_UUID} /* {PKG_PATH} */ = {{\n'
               f'\t\t\tisa = XCLocalSwiftPackageReference;\n'
               f'\t\t\trelativePath = {PKG_PATH};\n'
               f'\t\t}};\n')
c = c.replace('/* End XCLocalSwiftPackageReference section */',
              new_pkg_ref + '/* End XCLocalSwiftPackageReference section */')

new_prod_dep = (f'\t\t{PROD_UUID} /* {PKG_NAME} */ = {{\n'
                f'\t\t\tisa = XCSwiftPackageProductDependency;\n'
                f'\t\t\tpackage = {PKG_UUID} /* {PKG_PATH} */;\n'
                f'\t\t\tproductName = {PKG_NAME};\n'
                f'\t\t}};\n')
c = c.replace('/* End XCSwiftPackageProductDependency section */',
              new_prod_dep + '/* End XCSwiftPackageProductDependency section */')

c = c.replace(
    f'\t\t\t\tB1B2B3B4B5B6B7B8B9C0C1C2 /* XCLocalSwiftPackageReference "Packages/TraceFun" */,\n\t\t\t);',
    f'\t\t\t\tB1B2B3B4B5B6B7B8B9C0C1C2 /* XCLocalSwiftPackageReference "Packages/TraceFun" */,\n'
    f'\t\t\t\t{PKG_UUID} /* XCLocalSwiftPackageReference "{PKG_PATH}" */,\n\t\t\t);'
)
c = c.replace(
    f'\t\t\t\tD1D2D3D4D5D6D7D8D9E0E1E2 /* TraceFun */,\n\t\t\t);',
    f'\t\t\t\tD1D2D3D4D5D6D7D8D9E0E1E2 /* TraceFun */,\n'
    f'\t\t\t\t{PROD_UUID} /* {PKG_NAME} */,\n\t\t\t);'
)

with open('ColoringFun.xcodeproj/project.pbxproj', 'w') as f:
    f.write(c)
print('Done')
```

Verify + commit on Mac, patch to WSL:
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && xcodebuild ... build 2>&1 | grep -E '(error:|BUILD)'"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git add ColoringFun.xcodeproj/project.pbxproj && git commit -m 'chore: register XxxFun local package'"
ssh claude@192.168.50.251 "git -C ~/Dev/coloringApp format-patch HEAD~1 --stdout" > /tmp/patch.patch
git am /tmp/patch.patch && git push
```

## Current Status

### On device (shipped by garrettshannon):
- Hub 2×2 grid, all 11 original wife-feedback UX fixes, flyout panel architecture

### Built on simulator ✅, not yet deployed:
- Kid Mode full feature set (brush strip + builder + stamp grid + sounds)
- Spelling Fun + Trace Fun packages (registered, build clean)
- Feedback rounds 1–3 fixes (palette, stamps, brushes, sounds, colors)
- Trace Fun: coverage-based completion, even-odd P glyph fix, compact keyboard, outline checkpoint dots, view identity fix (2026-02-26)
- Crayon box color selector: **reverted** — needs redesign as tab within existing palette

### Planned (design + implementation plan complete, not yet built, as of 2026-02-27):
- Weather Fun: SpriteKit+SwiftUI weather app — design `docs/plans/2026-02-27-weather-fun-design.md`, plan `docs/plans/2026-02-27-weather-fun.md` (14 tasks)
- Hub layout change: 2×2 → 2×2 + centered bottom row for 5th app
- WeatherKit entitlement (Mac-side Xcode GUI step)
- DALL-E 3 asset generation + Pixabay/CC0 audio sourcing (manual steps)

### Untested on device (as of 2026-02-26):
- All simulator-only work above
- Voice recognition in SpellingFun, TraceFun, AppRequestView
- Drawing persistence across restarts (format changed — unified elements)
- Kid Mode portrait layout
- Z-axis toggle UX
- Stamp sounds (AVAudioSession fix added but untested)
- Brush builder slider effects (grain, bleed, transparency)
- Trace Fun coverage-based completion and checkpoint dot UX
