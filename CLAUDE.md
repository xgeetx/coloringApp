# Coloring App — Project Memory

## Project Overview
iPad SwiftUI coloring app for 3-year-olds. Located at `/Users/garrett/Claude/coloringApp/`.
Xcode project: `ColoringFun.xcodeproj` (iPad-only, iOS 16+, bundle ID `com.coloringapp.ColoringFun`).

## File Structure
```
coloringApp/
├── ColoringFun.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/contents.xcworkspacedata
└── ColoringApp/
    ├── ColoringApp.swift       — @main entry point
    ├── ContentView.swift       — root layout (toolbar + canvas + panels)
    ├── Models.swift            — DrawingState, Stroke, StampPlacement, CrayolaColor, BrushType
    ├── DrawingCanvasView.swift — Canvas rendering + DragGesture drawing
    ├── ColorPaletteView.swift  — 16 Crayola color swatches (bottom bar)
    ├── ToolsView.swift         — Brush type + size picker (left panel)
    ├── StampsView.swift        — Emoji stamp picker with categories (right panel)
    ├── TopToolbarView.swift    — Title, BG color picker, Undo, Clear
    └── Info.plist
```

## Architecture & Key Design Decisions
- **DrawingState** is an ObservableObject passed by reference to all views
- **Canvas** view used for rendering (not UIKit), with DragGesture for touch input
- Brush types: Crayon (3-pass textured), Marker (wide semi-transparent), Sparkle (star stamps along path), Eraser (marker with bg color)
- Stamp mode: DragGesture `.onEnded` places emoji; banner shown when active
- Undo uses parallel stacks: `strokeHistory` and `stampHistory`
- 16 Crayola colors defined as `CrayolaColor.palette` static array
- 4 stamp categories: Animals, Insects, Plants, Fun (emoji-only)
- Background color picks from 10 preset swatches via popover

## UI Layout (iPad landscape)
```
[Top Toolbar: title | BG Color | Undo | Clear]
[BrushTools 100pt] | [Drawing Canvas] | [Stamps 120pt]
[Color Palette — 16 Crayola swatches, bottom]
```

## First Pass Status
Initial version created (v1).

## NEXT SESSION WORK ITEM — Hub Architecture + App Store Assets

### What the user asked for (in order of priority):
1. **Hub/launcher screen** — "Kids Fun Zone" home screen with 2×2 grid of app tiles; only Coloring Fun exists now, 3 placeholder "Coming Soon" slots for future apps
2. **Multi-app architecture** — `AppRegistry.swift` with `MiniAppDescriptor` struct so future apps are added by dropping one entry in the registry
3. **Lower iOS deployment target** from 16.0 → **15.0** (for older iPads); all existing APIs already work on iOS 15, only the pbxproj needs updating
4. **Missing App Store assets** — app icon (1024×1024 PNG, generate via Python stdlib), privacy manifest (`PrivacyInfo.xcprivacy`), asset catalog

### Planned navigation model:
```
HubView (new root)
  └── fullScreenCover(item: $activeApp)
        └── ContentView() — coloring app
              └── TopToolbarView has 🏠 Home button → @Environment(\.dismiss)
```

### Files to CREATE:
- `ColoringApp/AppRegistry.swift` — `MiniAppDescriptor` struct + `AppRegistry.apps` static array
- `ColoringApp/HubView.swift` — 2×2 LazyVGrid of big tiles, `fullScreenCover` navigation
- `ColoringApp/Assets.xcassets/Contents.json`
- `ColoringApp/Assets.xcassets/AppIcon.appiconset/Contents.json` (1024 universal)
- `ColoringApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (Python-generated)
- `ColoringApp/PrivacyInfo.xcprivacy` (no tracking, empty arrays)

### Files to MODIFY:
- `ColoringApp/ColoringApp.swift` — root view: `ContentView()` → `HubView()`
- `ColoringApp/TopToolbarView.swift` — add `@Environment(\.dismiss)` + "🏠 Home" `ToolbarButton` at left of HStack
- `ColoringApp/Info.plist` — launch screen color, asset catalog ref
- `ColoringFun.xcodeproj/project.pbxproj` — add new files to Sources/Resources, drop deployment target to 15.0; regenerate via Python script

### AppRegistry design:
```swift
struct MiniAppDescriptor: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let icon: String          // emoji
    let accentColor: Color
    let tileColor: Color
    let isAvailable: Bool
    let makeRootView: () -> AnyView
    static func placeholder(id: String) -> Self { ... }
}
enum AppRegistry {
    static let apps: [MiniAppDescriptor] = [
        MiniAppDescriptor(id: "coloring", ..., makeRootView: { AnyView(ContentView()) }),
        .placeholder(id: "app2"), .placeholder(id: "app3"), .placeholder(id: "app4"),
    ]
}
```

### App icon generation: Python stdlib only (zlib + struct)
- 1024×1024 RGB PNG
- Build 8 unique row templates for 8×8 Crayola-colored grid
- Index into templates for each y row (fast — avoids 1M pixel loop)
- Gentle vignette to darken corners

### iOS 15 compat notes:
All current APIs are already iOS 15+. Only change = drop deployment target in pbxproj.
`Canvas`, `.ultraThinMaterial`, `.confirmationDialog`, `.foregroundStyle(LinearGradient)`, `fullScreenCover(item:)`, `@Environment(\.dismiss)` — all iOS 15+.
