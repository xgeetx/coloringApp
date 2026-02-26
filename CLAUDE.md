## ⚡ SESSION RESUME
All code built on simulator (BUILD SUCCEEDED). Unified feedback round complete. Next session = wife's new feedback.

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
│   ├── AppRegistry.swift           — MiniAppDescriptor + AppRegistry.apps; imports SpellingFun + TraceFun
│   ├── HubView.swift               — 2×2 grid launcher, triple-tap title to rename
│   ├── AppRequestView.swift        — voice dictation → email app request flow
│   ├── ContentView.swift           — parent-mode root: activeFlyout + strip/canvas/flyout layout
│   ├── Models.swift                — DrawingState, Stroke, StampPlacement, FlyoutPanel, BrushDescriptor, CrayolaColor, allStampCategories
│   ├── DrawingPersistence.swift    — Codable wrappers; CodableStampPlacement.opacity uses decodeIfPresent??1.0
│   ├── DrawingCanvasView.swift     — Canvas rendering; stamps rendered BEFORE strokes; eraser hit-tests stamps; pinch shows size indicator
│   ├── ColorPaletteView.swift      — ColorPicker pinned left + 16 Crayola swatches in horizontal ScrollView
│   ├── ToolsView.swift             — BrushesFlyoutView, SizeFlyoutView, OpacityFlyoutView, PoolPickerView
│   ├── StampsView.swift            — StampsFlyoutView(isKidMode:Bool=false), StampButton(fontSize:)
│   ├── TopToolbarView.swift        — Home, Title, BG color picker, Undo, Clear, Eraser toggle
│   ├── FlyoutContainerView.swift   — Generic flyout wrapper: slide animation, X button, shadow
│   ├── LeftStripView.swift         — 44pt icon strip (brush/size/opacity)
│   ├── RightStripView.swift        — 44pt icon strip (stamps only)
│   ├── BrushBuilderView.swift      — Full brush builder; opens as .sheet
│   ├── KidContentView.swift        — Kid-mode root + KidBrushPreview + KidBrushStripView + KidStampGridView + KidStampTile + StampSynth + stampSoundMap
│   ├── KidBrushBuilderView.swift   — Kid texture designer: delete row + 4 texture tiles + crayon has 2 sliders (soft/bold + tight/spread grain) + chalk uses particle cloud preview
│   └── Info.plist
├── Packages/                       — local Swift packages (NEVER touch project.pbxproj from WSL)
│   ├── SpellingFun/Sources/SpellingFun/SpellingView.swift
│   └── TraceFun/Sources/TraceFun/LetterTraceView.swift
└── docs/
    ├── feedback/
    │   ├── wife_feedback_02_24_2026.rtf  — text feedback (all 11 items addressed)
    │   └── wife_feedback_02_24_2026.caf  — voice recording (untranscribed)
    └── plans/                      — all executed; see Current Status below
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
- Current tiles: 🎨 Coloring Fun (`ContentView`), 🌈 Kids Mode (`KidContentView`), ✏️ Spelling Fun (`SpellingView`), 🖍️ Trace Fun (`LetterTraceView`)
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
- Right panel: `KidStampGridView` — 4 categories × 4 stamps with headers + "More" → `StampsFlyoutView(isKidMode: true)` sheet
- `KidBrushPreview` routes on `brush.baseStyle` for ALL brushes (system and user); only `.patternStamp` user brushes use splatter
- `KidBrushBuilderView`: delete row shows existing brushes with × button; crayon gets 2 sliders (soft/bold via `sizeVariation`, tight/spread grain via `stampSpacing`); chalk preview uses particle cloud; caps user brushes at 2
- `StampSynth` + `stampSoundMap` in `KidContentView.swift` — shared with `StampsView.swift` (internal access)
- `KidTopToolbarView` shows Size + Opacity sliders when `!isStampMode && !isEraserMode`
- No flyouts in kid mode; large targets (68pt buttons)
- iOS 15 compat: `kidSheetDetents()` / `kidDragIndicator()` `@ViewBuilder` extensions for `presentationDetents`/`presentationDragIndicator`

### Stamps
- `StampPlacement` has `opacity: Double` — baked from `brushOpacity` at placement time
- Stamps render BEFORE strokes in Canvas — paint/eraser goes on top of stamps
- Eraser hit-tests stamps during drag via `state.removeStamp(id:)` in `DrawingCanvasView`
- `StampsFlyoutView(isKidMode: true)` → 3-column grid, 48pt emoji, pastel category tabs (orange/green/pink/purple), TTS sound on tap
- Pinch gesture shows overlay: ghost stamp (stamp mode) or circle (brush mode)

### Spelling Fun — app3 (`Packages/SpellingFun`)
- Voice → confirm → letters scatter to stage → drag tiles to hear letters spoken
- `public struct SpellingView: View` + `public init() {}`; private `Color(r:g:b:)` + `Comparable.clamped(to:)` inlined

### Letter Trace Fun — app4 (`Packages/TraceFun`)
- Voice → confirm (no keyboard) → keyboard slides in → letters pop staggered (0.4s each) → trace with rainbow paint → celebrate
- State machine: `.idle → .listening → .confirm(word) → .tracing(word, letterIndex) → .celebrate(word)` in `LetterTraceViewModel (@MainActor)`
- Tracing: `Canvas { }` drawing rainbow circles, `.mask(Text(letter).font(...))` clips to letter glyph
- Completion: cumulative drag distance ≥ 350px; TTS says letter, auto-advances after 0.8s
- `public struct LetterTraceView: View` + `public init() {}`; private `Color(r:g:b:)` inlined

### Drawing Engine
- `DrawingState` is `ObservableObject`; `@StateObject` in root view — fresh per session, loads from disk on init
- 8 system brushes (fixed UUIDs): Crayon, Marker, Sparkle, Chalk, Hearts, Dots, Flowers, Confetti
- `.crayon`: 5-pass offset strokes + stipple grain dots (jitter indices 500+); `stampSpacing` controls grain spread for user brushes (0.45 × stampSpacing multiplier)
- `.marker`: wide transparent halo pre-pass + clean solid pass
- `.chalk`: pure particle cloud — 5 dots per point within `brushSize×0.6` spread, no stroke path
- `.patternStamp`: evenly spaced shape stamps along drag path
- Eraser: `BrushDescriptor.eraser` (UUID all-zeros), `renderHardErase()` at opacity 1.0; also hit-tests stamps
- Pinch resizes brush (6–80pt); `isPinching` flag prevents stroke artifacts
- Undo: parallel stacks `strokeHistory` + `stampHistory`

### Drawing Persistence
- Saved to `Documents/currentDrawing.json` (`.atomic` write)
- `CodableStroke.opacity` and `CodableStampPlacement.opacity` both use `decodeIfPresent ?? 1.0` for backward compat
- `persist()` (UserDefaults: brushes, opacity) is `internal`

### Project Config
- iOS 15.0 deployment target; `arm64`; `DEVELOPMENT_TEAM = T2DJZ649J4` committed in pbxproj

## Known Gotchas
- `MiniAppDescriptor` needs explicit `Equatable` — closures block synthesis
- New main-target `.swift` files need ALL 4 pbxproj insertions: **PBXBuildFile**, **PBXFileReference**, **PBXGroup children**, **PBXSourcesBuildPhase**
- New mini-apps → use Swift Package Protocol below; never hand-edit pbxproj SPM sections
- SSH deploys to iPad fail as `claude` — use Terminal as `garrettshannon`
- `AVAudioSession` must be configured before `inputNode` access
- `SFSpeechRecognizer` callbacks are off main thread — dispatch to main or use `@MainActor`
- `foregroundStyle` ternary needs explicit `Color.` types — Swift inference fails across `some ShapeStyle`
- `.onChange(of:)` use single-param form `{ newValue in }` — two-param `{ old, new in }` is iOS 17+ only
- `presentationDetents` / `presentationDragIndicator` are iOS 16+ — use `kidSheetDetents()` / `kidDragIndicator()` helpers
- `AVSpeechSynthesizer`: call `stopSpeaking(at: .immediate)` before each new utterance

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
- Package ref: `E1E2E3E4E5E6E7E8E9F0F1F2`
- Product dep: `F1F2F3F4F5F6F7F8F9A0A1A2`

**Used UUIDs (do not reuse):**
- `A1A2A3A4A5A6A7A8A9B0B1B2` — SpellingFun pkg ref
- `B1B2B3B4B5B6B7B8B9C0C1C2` — TraceFun pkg ref
- `C1C2C3C4C5C6C7C8C9D0D1D2` — SpellingFun product dep
- `D1D2D3D4D5D6D7D8D9E0E1E2` — TraceFun product dep

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
- Everything below — last BUILD SUCCEEDED after unified feedback round
- Kid Mode full feature set (brush strip + builder + stamp grid + sounds)
- Spelling Fun + Trace Fun packages (registered, build clean)
- Unified feedback fixes: portrait palette scroll, stamp opacity/render-order/eraser, brush builder improvements, stamp strip sounds

### Untested on device:
- All of the above simulator-only work
- Voice recognition in SpellingFun, TraceFun, AppRequestView
- Drawing persistence across restarts
- Kid Mode portrait layout
