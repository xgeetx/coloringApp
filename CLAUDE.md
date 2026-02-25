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
│   ├── AppRegistry.swift           — MiniAppDescriptor + AppRegistry.apps (4 tiles: Coloring Fun live, Kids Mode live, 2 placeholders)
│   ├── HubView.swift               — 2×2 grid launcher, triple-tap title to rename
│   ├── AppRequestView.swift        — voice dictation → email app request flow
│   ├── ContentView.swift           — parent-mode root: @State activeFlyout + strip/canvas/flyout layout
│   ├── Models.swift                — DrawingState, Stroke, FlyoutPanel enum, BrushDescriptor, CrayolaColor
│   ├── DrawingPersistence.swift    — Codable wrappers for Color, Stroke, StampPlacement, DrawingSnapshot
│   ├── DrawingCanvasView.swift     — Canvas rendering + DragGesture + MagnificationGesture; accepts dismissFlyout callback
│   ├── ColorPaletteView.swift      — 16 Crayola swatches + system ColorPicker (bottom bar)
│   ├── ToolsView.swift             — BrushesFlyoutView, SizeFlyoutView, OpacityFlyoutView, PoolPickerView, helper buttons
│   ├── StampsView.swift            — StampsFlyoutView (with onDismiss), StampButton
│   ├── TopToolbarView.swift        — Home, Title, BG color picker, Undo, Clear, Eraser toggle
│   ├── FlyoutContainerView.swift   — Generic flyout wrapper: slide animation, X button, shadow, white bg
│   ├── LeftStripView.swift         — 44pt icon strip (brush/size/opacity); StripIconButton shared component
│   ├── RightStripView.swift        — 44pt icon strip (stamps only)
│   ├── BrushBuilderView.swift      — Full brush builder (style + shape + sliders + name); currently sheet in parent mode
│   ├── KidContentView.swift        — [PLANNED] Kid-mode root: large brush strip, stamp grid, bottom colors
│   ├── KidBrushBuilderView.swift   — [PLANNED] Kid brush builder sheet with live interactive canvas preview
│   └── Info.plist
└── docs/
    ├── feedback/
    │   ├── wife_feedback_02_24_2026.rtf  — text feedback (all 11 items now addressed)
    │   └── wife_feedback_02_24_2026.caf  — voice recording (untranscribed)
    └── plans/
        ├── 2026-02-23-hub-architecture.md          — executed
        ├── 2026-02-24-drawing-persistence.md       — executed
        ├── 2026-02-24-wife-feedback-fixes.md       — executed (11 UX fixes)
        ├── 2026-02-24-flyout-popover-architecture-design.md  — design doc; implemented this session
        └── 2026-02-24-kid-mode-and-parent-fixes.md — PENDING; see plan for task list
            (tasks.json co-located)
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
- Current tiles: 🎨 Coloring Fun (`ContentView`), 🌈 Kids Mode (`KidContentView` — **planned, not yet built**), 🧩 Puzzle Play (placeholder), 📖 Story Time (placeholder)
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

### Kid Mode Architecture (planned — not yet implemented)
- Separate `KidContentView` with its own `@StateObject var state = DrawingState()` — drawings are independent from parent mode
- Left strip: texture brushes only (Crayon, Marker, Chalk, Sparkle + user-created) — no pattern-stamp brushes (hearts/flowers/confetti feel like "icons dragging around")
- Right panel: 8 always-visible stamps + "More ↓" button → `StampsFlyoutView` sheet
- `KidBrushBuilderView`: sheet (not fullscreen), live-draw preview canvas, 5 shape buttons, one spread slider, "Use This Brush!" save — no name entry
- No flyouts for brush/size/opacity in kid mode: everything always visible, large targets
- See `docs/plans/2026-02-24-kid-mode-and-parent-fixes.md` for full implementation plan

### Drawing Engine
- `DrawingState` is `ObservableObject`; created fresh per session via `@StateObject` in root view
- Each hub→app navigation creates a new root view → new `DrawingState` → `init()` loads from disk (seamless restore)
- 8 system brushes (fixed UUIDs): Crayon, Marker, Sparkle, Chalk, Hearts, Dots, Flowers, Confetti
- `BrushBaseStyle`: `.crayon` (5-pass textured, independent x/y jitter), `.marker`, `.chalk`, `.patternStamp`
- Eraser: `BrushDescriptor.eraser` (UUID all-zeros), `renderHardErase()` always at opacity 1.0
- Pinch gesture resizes brush (6–80pt); `isPinching` flag prevents stroke artifacts
- Stamp mode: tap places emoji at `brushSize × 2.8`; category switch auto-selects first stamp
- Undo: parallel stacks `strokeHistory` + `stampHistory`
- Per-stroke opacity baked in at `beginStroke()`; eraser always 1.0

### Custom Brush UX Gap (known issue, fix in plan)
- User creates a brush in `BrushBuilderView` → it's added to `brushPool` and persisted correctly
- BUT `BrushesFlyoutView` only shows 3 slot buttons; new brushes are invisible until long-pressed into a slot
- Fix (planned): show `brushPool.filter { !$0.isSystem }` directly in the flyout, remove slot paradigm from flyout UI

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

## Known Gotchas
- `MiniAppDescriptor` needs explicit `Equatable` — closures block synthesis
- New files need 4 manual insertions in `project.pbxproj`: PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase
- SSH deploys to iPad fail as `claude` — signing cert in `garrettshannon`'s keychain; use Xcode or Mac terminal as `garrettshannon`
- `AVAudioSession` must be configured before `inputNode` access in `AppRequestView`
- `SFSpeechRecognizer` callbacks are off main thread — always dispatch to main
- `foregroundStyle` ternary needs explicit `Color.` types — Swift inference fails across `some ShapeStyle` / `Color`
- `.onChange(of:)` two-parameter form is correct for iOS 15/16 (deprecation warning on 17+ unavoidable)
- Strip background must use `.ultraThinMaterial` not `.white.opacity(0.75)` — the latter is invisible on the app's light pastel gradient
- `BrushBuilderView` was `fullScreenCover` — jarring, feels like leaving the app. Fixed to `.sheet` in the pending plan.
- Mac `git pull` can fail if Xcode auto-modified `project.pbxproj` locally — run `git stash` on Mac first

## Current Status (as of 2026-02-25)

### Shipped and on device (installed by garrettshannon via Xcode):
- Hub architecture with 2×2 grid
- All 11 wife-feedback UX fixes
- Flyout panel architecture (strips + slide-in panels)

### Implemented this session, not yet on device:
- Flyout panel rearchitecture (committed, built on simulator ✅, not deployed to iPad)

### Known issues in current build (fixes in pending plan):
- Custom brushes invisible after creation (slot paradigm hidden — UX gap)
- `BrushBuilderView` is `fullScreenCover` (should be `.sheet`)
- Strip contrast low in portrait mode (`.ultraThinMaterial` fix pending)

### Next planned work:
- **Kid Mode + Parent Fixes** — `docs/plans/2026-02-24-kid-mode-and-parent-fixes.md` (status: **pending**)
  - 8 tasks: KidContentView, KidBrushBuilderView, pbxproj registration, AppRegistry tile, BrushBuilder sheet fix, pool display fix, strip contrast fix, final build

### Untested on device (as of 2026-02-25):
- Flyout panel architecture (portrait + landscape)
- Voice dictation → email in AppRequestView
- Drawing persistence across app restarts
- Hub navigation (home button, fullScreenCover dismiss)
