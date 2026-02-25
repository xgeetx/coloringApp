# Coloring App — Project Memory

## Project Overview
iPad SwiftUI coloring app for 3-year-olds.
GitHub: https://github.com/xgeetx/coloringApp

**Paths:**
- macOS (build machine): `/Users/claude/Dev/coloringApp/` (SSH: `claude@192.168.50.251`)
- WSL (editing machine): `/home/geet/Claude/coloringApp/`

**Workflow:** Code is edited in WSL, committed + pushed to GitHub, then SSH'd to Mac for `git pull` + `xcodebuild`.

**Build command (simulator):**
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Deploy to iPad:** Must run as `garrettshannon` — the `claude` SSH user can't access the signing certificate in `garrettshannon`'s keychain. Use Xcode directly or run xcodebuild in a Mac terminal as `garrettshannon`. iPad UDID: `28b1b65d4528209892b1ef4389dee775a537648b`.

Xcode project: `ColoringFun.xcodeproj` (iPad-only, iOS 15+, bundle ID `com.coloringapp.ColoringFun`).

## File Structure
```
coloringApp/
├── ColoringFun.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/contents.xcworkspacedata
├── ColoringApp/
│   ├── ColoringApp.swift         — @main entry point; root is HubView()
│   ├── AppRegistry.swift         — MiniAppDescriptor struct + AppRegistry.apps (4 tiles)
│   ├── HubView.swift             — Hub title (triple-tap to rename) + 2×2 grid launcher
│   ├── AppRequestView.swift      — voice dictation → email app request flow
│   ├── ContentView.swift         — root layout for coloring app (toolbar + canvas + panels)
│   ├── Models.swift              — DrawingState, Stroke, StampPlacement, CrayolaColor, BrushDescriptor
│   ├── DrawingPersistence.swift  — Codable wrappers for Color, Stroke, StampPlacement, DrawingSnapshot
│   ├── DrawingCanvasView.swift   — Canvas rendering + DragGesture drawing + MagnificationGesture
│   ├── ColorPaletteView.swift    — 16 Crayola swatches + system ColorPicker (bottom bar)
│   ├── ToolsView.swift           — Brush type, size, opacity picker (left panel)
│   ├── StampsView.swift          — Emoji stamp picker with categories (right panel)
│   ├── TopToolbarView.swift      — Title, BG color picker, Undo, Clear, 🏠 Home, Eraser
│   └── Info.plist
└── docs/
    └── plans/
        ├── 2026-02-23-hub-architecture-design.md
        ├── 2026-02-23-hub-architecture.md
        ├── 2026-02-24-drawing-persistence-design.md
        ├── 2026-02-24-drawing-persistence.md
        ├── 2026-02-24-wife-feedback-fixes-design.md   — design doc for 12 UX fixes
        ├── 2026-02-24-wife-feedback-fixes.md          — implementation plan (executed)
        ├── 2026-02-24-wife-feedback-fixes.md.tasks.json
        └── 2026-02-24-flyout-popover-architecture-design.md — NEXT: flyout panel rearchitecture
```

## Architecture & Key Design Decisions

### Navigation (Hub → App)
- `HubView` is the app root (set in `ColoringApp.swift`)
- `fullScreenCover(item: $activeApp)` launches a live app; `@Environment(\.dismiss)` in `TopToolbarView` provides the 🏠 Home button
- Placeholder tiles open a `sheet` with `AppRequestView`
- Hub title is user-editable: triple-tap to rename, persisted to `UserDefaults` key `"hubTitle"`, defaults to `"Triple Tap here to change Name"`

### AppRegistry
- `MiniAppDescriptor: Identifiable & Equatable` (Equatable is id-based — closures prevent synthesis)
- `makeRootView: () -> AnyView` closure lets each tile declare its own root view
- `AppRegistry.apps` has 4 entries: Coloring Fun (live) + 3 placeholders (Music Maker, Puzzle Play, Story Time)
- Add a new mini-app by adding one entry to `AppRegistry.apps` — no other changes needed

### App Request Flow (AppRequestView)
- 3-phase flow: `.prompt` → `.recording` → `.review`
- Uses `SFSpeechRecognizer` + `AVAudioEngine` for live speech-to-text
- **Critical ordering**: `AVAudioSession.setCategory` + `setActive` must happen BEFORE accessing `engine.inputNode` or calling `installTap`
- All `recognitionTask` callback mutations run on `DispatchQueue.main.async`
- Sends email to quintus851@gmail.com via `MFMailComposeViewController` (wrapped in `MailComposeView`)
- `.navigationViewStyle(.stack)` on wrapping `NavigationView` prevents iPad split-column layout

### Drawing (ContentView / DrawingCanvasView)
- `DrawingState` is an `ObservableObject` created fresh per coloring session via `@StateObject` in `ContentView`
- Each hub → app navigation creates a new `ContentView` (via `makeRootView`), which creates a new `DrawingState` — but `init()` loads from disk so the drawing is restored seamlessly
- Brushes described by `BrushDescriptor` (base style + optional pattern shape + spacing/variation params)
- 8 system brushes (fixed UUIDs, never deletable): Crayon, Marker, Sparkle (stars), Chalk, Hearts, Dots, Flowers, Confetti
- Eraser: special `BrushDescriptor.eraser` (UUID all-zeros), draws in background color at full opacity via `renderHardErase()` — bypasses the opacity layer, never enters the brush pool
- `BrushBaseStyle` enum: `.crayon` (5-pass textured with independent x/y jitter), `.marker` (wide semi-transparent), `.chalk`, `.patternStamp`
- Hearts brush: `sizeVariation: 0.0` (uniform) — was 0.25, changed after user feedback
- Per-stroke opacity: `Stroke.opacity` baked in at draw time from `DrawingState.brushOpacity`; eraser always 1.0
- Pinch gesture resizes brush (`MagnificationGesture` + `DragGesture.simultaneously`); `isPinching` flag prevents stroke artifacts during pinch
- 3 quick-access brush slots (`slotAssignments: [UUID?]`); user-created brushes saved to UserDefaults
- Stamp mode: tap places emoji at brushSize × 2.8; switching categories auto-selects first stamp in new category
- Undo uses parallel stacks: `strokeHistory` and `stampHistory`
- 16 Crayola colors + system `ColorPicker` in `CrayolaColor.palette` bar
- 4 stamp categories: Animals, Insects, Plants, Fun
- Brush size clamped to `6...80` via `Comparable.clamped(to:)` extension in `Models.swift`

### Drawing Persistence
- `DrawingState.init()` calls `loadPersistedState()` which calls `loadDrawing()` — always reopens last drawing
- `persistDrawing()` called at end of `endStroke()`, `placeStamp()`, `undo()`, `clear()`
- `persist()` (UserDefaults — brushes, slots, opacity) is `internal` so ToolsView can call it on slider change
- Saved to `Documents/currentDrawing.json` with `.atomic` write option
- `SwiftUI.Color` is not Codable — bridged via `CodableColor` using `UIColor.getRed(_:green:blue:alpha:)`
- `DrawingSnapshot` contains `[CodableStroke]`, `[CodableStampPlacement]`, and `CodableColor` for background
- `CodableStroke` includes `opacity: Double` with `decodeIfPresent ?? 1.0` for backward compat with old saves
- `brushOpacity` persisted to UserDefaults key `"brushOpacity"`

### UI Layout (iPad landscape)
```
[🏠 Home | Title | BG Color | Undo | Clear | 🔸 Eraser]  ← TopToolbarView
[BrushTools 100pt] | [Drawing Canvas] | [Stamps 120pt]
[Color Palette — 16 Crayola swatches + ColorPicker, bottom]
```
- Eraser is a toggle button in the top toolbar (orange, shows border when active)
- Background color picker has 24 swatches (neutrals, pastels, brights, darks) + custom `ColorPicker`
- Opacity slider in ToolsView (0.1–1.0, step 0.05) with live color preview swatch

### Project Config
- Deployment target: iOS 15.0 (all 4 build configurations in pbxproj)
- Required device capability: `arm64`
- Microphone + speech recognition usage descriptions in Info.plist
- `UIDeviceFamily` removed from Info.plist — `TARGETED_DEVICE_FAMILY` build setting handles it

## Known Gotchas
- `MiniAppDescriptor` needs explicit `Equatable` — closures block synthesis
- `AVAudioSession` must be configured before `inputNode` access in AppRequestView
- `SFSpeechRecognizer` callbacks are off main thread — always dispatch to main
- New files need 4 manual insertions in `project.pbxproj`: PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase
- SSH deploys to iPad fail as `claude` user — signing cert is in `garrettshannon`'s keychain; use Xcode or Mac terminal as `garrettshannon`
- `chmod` without `-R` only affects the directory itself, not files inside — use `-R` when granting write access recursively
- `foregroundStyle` ternary expressions need explicit `Color.` types (e.g. `Color.primary`, `Color.accentColor`) — Swift type inference fails when one branch returns `some ShapeStyle` and the other `Color`
- `.onChange(of:)` two-parameter closure form is correct for iOS 15/16; iOS 17+ prefers zero-parameter form (deprecation warning on 17+, unavoidable for single-target compat)
- `@State var hubTitle = UserDefaults...` initialization is reliable for root views; prefer `@AppStorage` in future for two-way binding

## Current Status
All wife-feedback UX fixes built, reviewed, and pushed. App has been installed on the physical iPad (deployed manually via Xcode by garrettshannon).

### Next planned work:
- **Flyout panel rearchitecture** — design doc at `docs/plans/2026-02-24-flyout-popover-architecture-design.md`. Replace fixed side panels with narrow icon strips + slide-in flyout panels. Run AFTER current changes are verified on device.

### Untested flows (on device):
- Voice dictation → email in AppRequestView
- Drawing persistence across app restarts
- Hub navigation (home button, fullScreenCover dismiss)
- All 12 wife-feedback fixes (installed but not yet validated on device)
