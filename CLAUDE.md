## ⚡ SESSION RESUME
At the start of this session, read `docs/plans/2026-02-25-spelling-fun.md`, tell the user you're ready to continue from Task 1 (create SpellingView.swift), then wait for their go-ahead.

# Coloring App — Project Memory

## Project Overview
iPad SwiftUI coloring app for 3-year-olds.
GitHub: https://github.com/xgeetex/coloringApp

**Paths:**
- macOS (build machine): `/Users/claude/Dev/coloringApp/` (SSH: `claude@192.168.50.251`)
- WSL (editing machine): `/home/geet/Claude/coloringApp/`

**Workflow:** Code is edited in WSL, committed + pushed to GitHub, then SSH'd to Mac for `git pull` + `xcodebuild`.

**Build command (simulator):**
```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Mac dirty-worktree gotcha:** If `git pull` fails on the Mac with "local changes would be overwritten", run `git stash` first on the Mac, then pull.

**Deploy to iPad:** Must run as `garrettshannon` — the `claude` SSH user can't access the signing certificate in `garrettshannon`'s keychain. Use Xcode directly. iPad UDID: `28b1b65d4528209892b1ef4389dee775a537648b`.

Xcode project: `ColoringFun.xcodeproj` (iPad-only, iOS 15+, bundle ID `com.coloringapp.ColoringFun`).

**Wife feedback files:** `docs/feedback/wife_feedback_02_24_2026.rtf` + `.caf` (voice recording, untranscribed).

## File Structure
```
coloringApp/
├── ColoringFun.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/contents.xcworkspacedata
├── ColoringApp/
│   ├── ColoringApp.swift           — @main entry; root is HubView()
│   ├── AppRegistry.swift           — MiniAppDescriptor + AppRegistry.apps (🎨 Coloring Fun, 🌈 Kids Mode, ✏️ Spelling Fun, 🖍️ Trace Fun — all 4 live)
│   ├── HubView.swift               — 2×2 grid launcher, triple-tap title to rename
│   ├── AppRequestView.swift        — voice dictation → email app request flow
│   ├── ContentView.swift           — parent-mode root: @State activeFlyout + strip/canvas/flyout layout
│   ├── Models.swift                — DrawingState, Stroke, FlyoutPanel enum, BrushDescriptor, CrayolaColor
│   ├── DrawingPersistence.swift    — Codable wrappers for Color, Stroke, StampPlacement, DrawingSnapshot
│   ├── DrawingCanvasView.swift     — Canvas rendering + DragGesture + MagnificationGesture; accepts dismissFlyout callback
│   ├── ColorPaletteView.swift      — 16 Crayola swatches + system ColorPicker (bottom bar)
│   ├── ToolsView.swift             — BrushesFlyoutView (direct pool listing), SizeFlyoutView, OpacityFlyoutView, PoolPickerView
│   ├── StampsView.swift            — StampsFlyoutView (with onDismiss), StampButton
│   ├── TopToolbarView.swift        — Home, Title, BG color picker, Undo, Clear, Eraser toggle
│   ├── FlyoutContainerView.swift   — Generic flyout wrapper: slide animation, X button, shadow
│   ├── LeftStripView.swift         — 44pt icon strip (brush/size/opacity); StripIconButton shared component
│   ├── RightStripView.swift        — 44pt icon strip (stamps only)
│   ├── BrushBuilderView.swift      — Full brush builder (style + shape + sliders + name); opens as .sheet
│   ├── KidContentView.swift        — Kid-mode root: texture brush strip (left), 8-stamp grid (right), canvas (centre), ColorPalette (bottom), top toolbar with Size+Opacity sliders (brush mode) + Undo/Erase/Clear/Home; includes KidBrushPreview, KidBrushButton, KidBrushStripView, KidSlider; iOS 15 compat via @available(iOS 16) sheet helpers
│   ├── KidBrushBuilderView.swift   — Kid texture designer: 4 texture tiles (Crayon/Marker/Chalk/Glitter via KidBrushPreview), contextual slider (soft↔bold or dense↔spread), live-draw canvas, auto-names + auto-selects on save; KidTexturePickerTile struct
│   ├── SpellingView.swift          — app3 Spelling Fun: voice → letter tiles auto-animate to stage, drag-to-speak (exists on disk + pbxproj, uncommitted)
│   └── LetterTraceView.swift       — app4 Trace Fun: voice → confirm → keyboard slides in → letters pop staggered → trace each letter with rainbow paint (Canvas+mask)
│   └── Info.plist
└── docs/
    ├── feedback/
    │   ├── wife_feedback_02_24_2026.rtf  — text feedback (all 11 items addressed)
    │   └── wife_feedback_02_24_2026.caf  — voice recording (untranscribed)
    ├── ideas/
    │   └── letter_drawing              — source idea for Spelling Fun (voice → big draggable letters)
    └── plans/
        ├── 2026-02-23-hub-architecture.md                      — executed
        ├── 2026-02-24-drawing-persistence.md                   — executed
        ├── 2026-02-24-wife-feedback-fixes.md                   — executed (11 UX fixes)
        ├── 2026-02-24-flyout-popover-architecture-design.md    — design doc; implemented
        ├── 2026-02-24-kid-mode-and-parent-fixes.md             — executed (2026-02-25)
        ├── 2026-02-25-kid-mode-ux-fixes.md                     — executed (2026-02-25)
        ├── 2026-02-25-kid-brush-previews.md                    — executed (2026-02-25)
        ├── 2026-02-25-brush-rendering-and-kid-sliders.md       — executed (2026-02-25)
        ├── 2026-02-25-spelling-fun.md                          — PENDING (Task 1 next: create SpellingView.swift)
        └── 2026-02-25-letter-trace-fun.md                      — executed (2026-02-25)
```

## Architecture & Key Design Decisions

### Navigation (Hub → App)
- `HubView` is app root (`ColoringApp.swift`)
- `fullScreenCover(item: $activeApp)` launches live apps; `@Environment(\.dismiss)` in each app's toolbar provides 🏠 Home
- Placeholder tiles open a `sheet` with `AppRequestView`
- Hub title triple-tap to rename, persisted to `UserDefaults["hubTitle"]`

### AppRegistry
- `MiniAppDescriptor: Identifiable & Equatable` (Equatable is id-based — closures block synthesis)
- `makeRootView: () -> AnyView` — each tile declares its own root
- Current tiles: 🎨 Coloring Fun (`ContentView`), 🌈 Kids Mode (`KidContentView`), ✏️ Spelling Fun (`SpellingView` — app3, uncommitted), 🖍️ Trace Fun (`LetterTraceView` — app4, built on simulator)
- Add new app: one entry in `AppRegistry.apps`, no other changes

### Flyout Panel Architecture (ContentView — parent mode)
- `@State var activeFlyout: FlyoutPanel?` in `ContentView` controls which panel is open (`nil` = all closed)
- `FlyoutPanel` enum in `Models.swift`: `.brushes`, `.size`, `.opacity`, `.stamps`
- Layout: `LeftStripView (44pt) | ZStack(canvas + flyout overlays) | RightStripView (44pt)`
- Left flyouts slide over canvas from leading edge; stamps flyout from trailing edge
- `FlyoutContainerView` is a generic `@ViewBuilder` wrapper: X button, shadow, `.ultraThinMaterial`-ish white bg
- `DrawingCanvasView` accepts `dismissFlyout: (() -> Void)?` — called when a new stroke begins
- Strip background is `.ultraThinMaterial` — **must not use** `.white.opacity(0.75)` (invisible on light gradient)
- Transitions: `.move(edge:)` + `.animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeFlyout)`

### Kid Mode Architecture (implemented 2026-02-25; UX polished 2026-02-25)
- Separate `KidContentView` with its own `@StateObject var state = DrawingState()` — drawings are independent from parent mode
- Left strip: texture brushes only (Crayon, Marker, Chalk, Sparkle + user-created) — no pattern-stamp brushes
- Right panel: 8 always-visible stamps + "More ↓" button → `StampsFlyoutView` sheet
- `KidBrushButton` shows a live `KidBrushPreview` (static Canvas render per medium) instead of an emoji icon
- `KidBrushPreview` — routes on `brush.isSystem`: system brushes get a distinct static render per `baseStyle` (crayon=diagonal band+grain stipple, marker=horizontal stroke+halo, chalk=diagonal passes+dust, sparkle=scattered stars); user brushes get a seeded splatter dot cloud
- `KidBrushStripView` takes `systemBrushes` + `userBrushes` as separate arrays; user brushes appear inside a dashed purple-bordered box above the Make button
- `KidBrushBuilderView`: texture designer — 4 tiles (Crayon/Marker/Chalk/Glitter), contextual slider (soft↔bold for texture brushes, dense↔spread for Glitter), live-draw canvas preview, auto-names + auto-selects on save; caps user brushes at 2 (oldest removed on save)
- `sizeVariation` wired into `renderCrayon`/`renderMarker`/`renderChalk` as `opacityScale` for non-system brushes only — system brushes unchanged
- `KidTopToolbarView` shows Size + Opacity `KidSlider` components in the spacer zone when `!isStampMode && !isEraserMode`; sliders bind directly to `state.brushSize` (6–80) and `state.brushOpacity` (0.2–1.0)
- No flyouts in kid mode: everything always visible, large targets (68pt buttons)
- Portrait fix: `DrawingCanvasView` gets `.frame(maxWidth: .infinity, maxHeight: .infinity)`; main HStack gets `.frame(maxHeight: .infinity)`
- iOS 15 compat: `presentationDetents` wrapped in `kidSheetDetents()` / `kidDragIndicator()` `@ViewBuilder` extensions using `#available(iOS 16, *)`

### Spelling Fun — app3 (see docs/plans/2026-02-25-spelling-fun.md — PENDING)
- `SpellingView.swift`: voice → confirm → all letters scatter onto stage → drag tiles to hear letters spoken
- pbxproj UUIDs: PBXBuildFile `E6F6A7B8C9D0E1F2A3B4C5D6`, PBXFileRef `F7A7B8C9D0E1F2A3B4C5D6E7`
- File exists on disk + in pbxproj but **not committed yet**

### Letter Trace Fun — app4 (see docs/plans/2026-02-25-letter-trace-fun.md — executed 2026-02-25)
- `LetterTraceView.swift`: voice → confirm → keyboard slides in → letters pop out staggered (0.4s each) → trace each letter with rainbow paint → celebrate
- State machine: `.idle → .listening → .confirm(word) → .tracing(word, letterIndex) → .celebrate(word)` in `LetterTraceViewModel (@MainActor)`
- **Screen 1 (mic) and Screen 2 (confirm) have NO keyboard** — keyboard appears only when tracing begins
- Letter pop animation: `.transition(.move(edge: .bottom).combined(with: .scale(0.2).combined(with: .opacity)))` with staggered `DispatchQueue.asyncAfter` at 0.4s intervals; guard against double-pop with `tiles.allSatisfy({ !$0.hasPopped })`
- Tracing paint: `Canvas { ... }` drawing rainbow circles at drag points, `.mask(Text(letter).font(...))` clips paint to the letter glyph shape exactly
- Completion: cumulative drag distance ≥ 350px (no pixel-coverage needed); TTS says letter on complete, auto-advances after 0.8s
- Progress dots + small tile row + big centered letter + read-only keyboard panel layout
- pbxproj UUIDs: PBXBuildFile `A8B8C9D0E1F2A3B4C5D6E7F8`, PBXFileRef `B9C9D0E1F2A3B4C5D6E7F8A9`

### BrushesFlyoutView (parent mode)
- User brushes shown directly below system brushes via `state.brushPool.filter { !$0.isSystem }` — no slot paradigm in flyout UI
- `BrushBuilderView` opens as `.sheet` (was `fullScreenCover` — jarring, felt like leaving the app)
- `PoolPickerView` struct retained in `ToolsView.swift` but not used from flyout

### Drawing Engine
- `DrawingState` is `ObservableObject`; created fresh per session via `@StateObject` in root view
- Each hub→app navigation creates a new root view → new `DrawingState` → `init()` loads from disk (seamless restore)
- 8 system brushes (fixed UUIDs): Crayon, Marker, Sparkle, Chalk, Hearts, Dots, Flowers, Confetti
- `BrushBaseStyle`: `.crayon` (5-pass offset strokes + stipple grain dots every-other-point, jitter indices 500+ avoid collision with pass jitter 0–4/100–104), `.marker` (wide transparent halo pre-pass + clean solid pass, no texture), `.chalk` (pure particle cloud — 5 dots per point within `brushSize×0.6` spread, no stroke path at all), `.patternStamp`
- `PatternShape.path(center:size:)` — shape math centralized in `Models.swift`; `DrawingCanvasView.pathForShape` and preview canvases all delegate to it
- Eraser: `BrushDescriptor.eraser` (UUID all-zeros), `renderHardErase()` always at opacity 1.0
- Pinch gesture resizes brush (6–80pt); `isPinching` flag prevents stroke artifacts
- Stamp mode: tap places emoji at `brushSize × 2.8`; category switch auto-selects first stamp
- Undo: parallel stacks `strokeHistory` + `stampHistory`
- Per-stroke opacity baked in at `beginStroke()`; eraser always 1.0

### Drawing Persistence
- Saved to `Documents/currentDrawing.json` (`.atomic` write)
- `persist()` (UserDefaults: brushes, slots, opacity) is `internal` so views can call it directly
- `CodableStroke.opacity` uses `decodeIfPresent ?? 1.0` for backward compat
- `brushOpacity` → `UserDefaults["brushOpacity"]`

### UI Layout (parent mode, iPad landscape)
```
[🏠 Home | 🎨 Coloring Fun! | BG Color | Undo | Clear | Eraser]  ← TopToolbarView
[LeftStrip 44pt] | [Canvas + flyout overlays] | [RightStrip 44pt]
[Color Palette — 16 Crayola swatches + ColorPicker, bottom]
```
Flyout widths: 260pt, slide over canvas. Canvas gains ~112pt vs old fixed-panel layout.

### Project Config
- Deployment target: iOS 15.0
- Required device capability: `arm64`
- `UIDeviceFamily` removed from Info.plist — `TARGETED_DEVICE_FAMILY` build setting handles it
- `DEVELOPMENT_TEAM = T2DJZ649J4` committed in both Debug/Release configs — survives `git pull` on Mac without clearing signing

## Known Gotchas
- `MiniAppDescriptor` needs explicit `Equatable` — closures block synthesis
- New files need ALL 4 manual insertions in `project.pbxproj`: **PBXBuildFile**, **PBXFileReference**, **PBXGroup children**, **PBXSourcesBuildPhase** — missing the last two causes "cannot find X in scope" build error even though the file physically exists
- SSH deploys to iPad fail as `claude` — signing cert in `garrettshannon`'s keychain; use Xcode or Mac terminal as `garrettshannon`
- `AVAudioSession` must be configured before `inputNode` access (see AppRequestView / SpellingView pattern)
- `SFSpeechRecognizer` callbacks are off main thread — always dispatch to main (or use `@MainActor` class)
- `foregroundStyle` ternary needs explicit `Color.` types — Swift inference fails across `some ShapeStyle` / `Color`
- `.onChange(of:)` use single-param form `{ newValue in }` for iOS 15/16 — the two-param `{ old, new in }` form is iOS 17+ API only
- Strip background must use `.ultraThinMaterial` not `.white.opacity(0.75)` — the latter is invisible on the app's light pastel gradient
- `presentationDetents` / `presentationDragIndicator` are iOS 16+ — wrap in `#available(iOS 16, *)` `@ViewBuilder` helpers for iOS 15 compat
- Mac `git pull` can fail if Xcode auto-modified `project.pbxproj` locally — run `git stash` on Mac first
- `AVSpeechSynthesizer`: call `stopSpeaking(at: .immediate)` before each new utterance to prevent a speech queue backlog

## Current Status (as of 2026-02-25)

### Shipped and on device (installed by garrettshannon via Xcode):
- Hub architecture with 2×2 grid
- All 11 wife-feedback UX fixes
- Flyout panel architecture (strips + slide-in panels)

### Built on simulator ✅, not yet deployed to iPad:
- Flyout panel rearchitecture
- Kid Mode (`KidContentView` + `KidBrushBuilderView`)
- Parent mode fixes: BrushBuilder as sheet, direct user brush listing, strip contrast
- Kid Mode UX polish: texture previews in brush strip, portrait layout fix, texture designer builder, sizeVariation opacity scaling (untested as of 2026-02-25)
- Kid brush preview overhaul: distinct static renders per medium + splatter for user brushes + bordered user-brush box (untested as of 2026-02-25)
- Brush rendering overhaul: crayon stipple grain, marker ink-bleed halo, chalk pure particle cloud — both parent + kid mode (untested as of 2026-02-25)
- Kid mode Size + Opacity sliders in top bar (untested as of 2026-02-25)
- Trace Fun (`LetterTraceView`) — full voice-to-trace flow, BUILD SUCCEEDED (untested on device as of 2026-02-25)

### Pending — exists on disk, needs commit + build:
- Spelling Fun (`SpellingView`) — plan at docs/plans/2026-02-25-spelling-fun.md

### Untested on device (as of 2026-02-25):
- Trace Fun: full flow, voice recognition, letter pop animation, rainbow paint tracing, TTS
- Kid Mode layout (portrait + landscape)
- Kid brush builder live canvas preview
- Flyout panel architecture (portrait + landscape)
- Voice dictation → email in AppRequestView
- Drawing persistence across app restarts
- Hub navigation (home button, fullScreenCover dismiss)
