# Drawing Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Persist the current drawing to `Documents/currentDrawing.json` so it survives hub navigation and app restarts, always opening the last drawing.

**Architecture:** A new `DrawingPersistence.swift` introduces Codable wrappers for `SwiftUI.Color`, `StrokePoint`, `Stroke`, and `StampPlacement` (none of which are currently Codable), plus a `DrawingSnapshot` container. `DrawingState` gains `persistDrawing()` and `loadDrawing()` methods; `persistDrawing()` is called at the end of every mutation (`endStroke`, `placeStamp`, `undo`, `clear`). No structural refactor — `ContentView` keeps its `@StateObject DrawingState`, which reloads from disk on every `init()`.

**Tech Stack:** SwiftUI, Foundation (`FileManager`, `JSONEncoder/Decoder`), `UIKit.UIColor` (for `Color` → RGBA bridging).

---

### Task 1: Create DrawingPersistence.swift

**Files:**
- Create: `ColoringApp/DrawingPersistence.swift`

`SwiftUI.Color` cannot be round-tripped through `Codable` directly. We bridge via `UIColor.getRed(_:green:blue:alpha:)` which is always available on iOS 15+.

`Stroke` has `let id = UUID()` — the synthesized memberwise init gives `id` a default, so `Stroke(points:color:brushSize:brush:)` works fine and produces a fresh UUID on restore (IDs are only used for `ForEach` identity, so this is correct).

**Step 1: Write the file**

```swift
import SwiftUI

// MARK: - Codable Color Bridge

struct CodableColor: Codable {
    let r, g, b, a: Double

    init(_ color: Color) {
        let ui = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        (r, g, b, a) = (Double(red), Double(green), Double(blue), Double(alpha))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

// MARK: - Codable Stroke Point

struct CodableStrokePoint: Codable {
    let x, y: Double

    init(_ point: StrokePoint) {
        x = Double(point.location.x)
        y = Double(point.location.y)
    }

    var strokePoint: StrokePoint {
        StrokePoint(location: CGPoint(x: x, y: y))
    }
}

// MARK: - Codable Stroke

struct CodableStroke: Codable {
    let points: [CodableStrokePoint]
    let color: CodableColor
    let brushSize: Double
    let brush: BrushDescriptor   // already Codable

    init(_ stroke: Stroke) {
        points    = stroke.points.map { CodableStrokePoint($0) }
        color     = CodableColor(stroke.color)
        brushSize = Double(stroke.brushSize)
        brush     = stroke.brush
    }

    var stroke: Stroke {
        Stroke(
            points:    points.map { $0.strokePoint },
            color:     color.color,
            brushSize: CGFloat(brushSize),
            brush:     brush
        )
    }
}

// MARK: - Codable Stamp Placement

struct CodableStampPlacement: Codable {
    let emoji: String
    let x, y, size: Double

    init(_ stamp: StampPlacement) {
        emoji = stamp.emoji
        x     = Double(stamp.location.x)
        y     = Double(stamp.location.y)
        size  = Double(stamp.size)
    }

    var stampPlacement: StampPlacement {
        StampPlacement(
            emoji:    emoji,
            location: CGPoint(x: x, y: y),
            size:     CGFloat(size)
        )
    }
}

// MARK: - Drawing Snapshot

struct DrawingSnapshot: Codable {
    let strokes:         [CodableStroke]
    let stamps:          [CodableStampPlacement]
    let backgroundColor: CodableColor
}
```

**Step 2: Verify file was created**

```bash
wc -l /home/geet/Claude/coloringApp/ColoringApp/DrawingPersistence.swift
```
Expected: ~80 lines.

**Step 3: Commit**

```bash
git -C /home/geet/Claude/coloringApp add ColoringApp/DrawingPersistence.swift
git -C /home/geet/Claude/coloringApp commit -m "feat: add Codable drawing snapshot types"
```

---

### Task 2: Extend DrawingState in Models.swift

**Files:**
- Modify: `ColoringApp/Models.swift`

Four changes, applied in order:

**Change A — Rename `loadFromUserDefaults()` → `loadPersistedState()` and call `loadDrawing()` at end**

Find the existing `init()` block:
```swift
init() {
    loadFromUserDefaults()
}
```
Change to:
```swift
init() {
    loadPersistedState()
}
```

Find the existing private function declaration:
```swift
private func loadFromUserDefaults() {
```
Change to:
```swift
private func loadPersistedState() {
```

At the end of `loadPersistedState()`, after the `slotAssignments` block and before the closing `}`, add:
```swift
        loadDrawing()
```

**Change B — Add `drawingFileURL`, `persistDrawing()`, `loadDrawing()` helpers**

At the end of the `// MARK: - Persistence` section (after the closing `}` of `persist()`), add:

```swift
    private var drawingFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("currentDrawing.json")
    }

    func persistDrawing() {
        let snapshot = DrawingSnapshot(
            strokes:         strokes.map { CodableStroke($0) },
            stamps:          stamps.map { CodableStampPlacement($0) },
            backgroundColor: CodableColor(backgroundColor)
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: drawingFileURL, options: .atomic)
        }
    }

    private func loadDrawing() {
        guard let data = try? Data(contentsOf: drawingFileURL),
              let snapshot = try? JSONDecoder().decode(DrawingSnapshot.self, from: data)
        else { return }
        strokes         = snapshot.strokes.map { $0.stroke }
        stamps          = snapshot.stamps.map  { $0.stampPlacement }
        backgroundColor = snapshot.backgroundColor.color
    }
```

**Change C — Add `persistDrawing()` call to `endStroke()`**

Find:
```swift
    func endStroke() {
        guard let stroke = currentStroke else { return }
        strokeHistory.append(strokes)
        strokes.append(stroke)
        currentStroke = nil
    }
```
Change to:
```swift
    func endStroke() {
        guard let stroke = currentStroke else { return }
        strokeHistory.append(strokes)
        strokes.append(stroke)
        currentStroke = nil
        persistDrawing()
    }
```

**Change D — Add `persistDrawing()` to `placeStamp()`, `undo()`, `clear()`**

Find `placeStamp`:
```swift
    func placeStamp(at point: CGPoint) {
        stampHistory.append(stamps)
        stamps.append(StampPlacement(
            emoji: selectedStamp,
            location: point,
            size: brushSize * 2.8
        ))
    }
```
Change to:
```swift
    func placeStamp(at point: CGPoint) {
        stampHistory.append(stamps)
        stamps.append(StampPlacement(
            emoji: selectedStamp,
            location: point,
            size: brushSize * 2.8
        ))
        persistDrawing()
    }
```

Find `undo`:
```swift
    func undo() {
        if !strokeHistory.isEmpty { strokes = strokeHistory.removeLast() }
        if !stampHistory.isEmpty  { stamps  = stampHistory.removeLast()  }
    }
```
Change to:
```swift
    func undo() {
        if !strokeHistory.isEmpty { strokes = strokeHistory.removeLast() }
        if !stampHistory.isEmpty  { stamps  = stampHistory.removeLast()  }
        persistDrawing()
    }
```

Find `clear`:
```swift
    func clear() {
        strokeHistory.append(strokes)
        stampHistory.append(stamps)
        strokes = []
        stamps = []
        currentStroke = nil
    }
```
Change to:
```swift
    func clear() {
        strokeHistory.append(strokes)
        stampHistory.append(stamps)
        strokes = []
        stamps = []
        currentStroke = nil
        persistDrawing()
    }
```

**Step: Verify the key landmarks are correct**

```bash
grep -n "persistDrawing\|loadDrawing\|loadPersistedState\|drawingFileURL" /home/geet/Claude/coloringApp/ColoringApp/Models.swift
```

Expected output — should see all 4 method names, `persistDrawing()` appearing 5 times (definition + 4 call sites), `loadDrawing()` twice (definition + call in `loadPersistedState`).

**Step: Commit**

```bash
git -C /home/geet/Claude/coloringApp add ColoringApp/Models.swift
git -C /home/geet/Claude/coloringApp commit -m "feat: persist drawing to Documents on every mutation, reload on init"
```

---

### Task 3: Register DrawingPersistence.swift in project.pbxproj

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj`

Use these UUIDs (chosen to not conflict with any existing entries):

| File | fileRef UUID | buildFile UUID |
|------|-------------|----------------|
| DrawingPersistence.swift | `11A1B1C1D1E1F1A2B2C2D2E2` | `22A2B2C2D2E2F2A3B3C3D3E3` |

**Step 1: Add PBXBuildFile entry**

Find `/* End PBXBuildFile section */` and insert before it:
```
		22A2B2C2D2E2F2A3B3C3D3E3 /* DrawingPersistence.swift in Sources */ = {isa = PBXBuildFile; fileRef = 11A1B1C1D1E1F1A2B2C2D2E2 /* DrawingPersistence.swift */; };
```

**Step 2: Add PBXFileReference entry**

Find `/* End PBXFileReference section */` and insert before it:
```
		11A1B1C1D1E1F1A2B2C2D2E2 /* DrawingPersistence.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DrawingPersistence.swift; sourceTree = "<group>"; };
```

**Step 3: Add to PBXGroup children**

Find `238243F2CAD1B7AD4D521E07 /* Info.plist */,` inside the ColoringApp group and insert after it (before the closing `);`):
```
				11A1B1C1D1E1F1A2B2C2D2E2 /* DrawingPersistence.swift */,
```

**Step 4: Add to PBXSourcesBuildPhase files**

Find `FE01AF02BA03CB04DC05ED06 /* AppRequestView.swift in Sources */,` (the last Sources entry from the previous task) and insert after it:
```
				22A2B2C2D2E2F2A3B3C3D3E3 /* DrawingPersistence.swift in Sources */,
```

**Step 5: Verify**

```bash
grep -c "DrawingPersistence" /home/geet/Claude/coloringApp/ColoringFun.xcodeproj/project.pbxproj
```
Expected: `4`

**Step 6: Commit**

```bash
git -C /home/geet/Claude/coloringApp add ColoringFun.xcodeproj/project.pbxproj
git -C /home/geet/Claude/coloringApp commit -m "chore: register DrawingPersistence.swift in Xcode project"
```

---

### Task 4: Push and verify on device

**Step 1: Push**

```bash
git -C /home/geet/Claude/coloringApp push origin main
```

**Step 2: Pull and open on macOS**

```bash
git pull
open ColoringFun.xcodeproj
```

**Step 3: Build and test (⌘B then run)**

Verify:
- Build succeeds with no errors or warnings about `DrawingPersistence`
- Draw something, tap Home → re-open Coloring Fun → drawing is still there
- Draw something, force-quit the app, relaunch → drawing is still there
- Tap Clear → drawing is gone; relaunch → blank canvas (Clear persisted correctly)
- `Documents/currentDrawing.json` exists in the app sandbox after first stroke (visible in Xcode's device file browser: Window → Devices and Simulators → your device → select app → download container)

---

## iOS 15 Compatibility

All new APIs:

| API | Min iOS |
|-----|---------|
| `UIColor(color:)` SwiftUI init | iOS 14 |
| `UIColor.getRed(_:green:blue:alpha:)` | iOS 2 |
| `FileManager.urls(for:in:)` | iOS 2 |
| `JSONEncoder` / `JSONDecoder` | iOS 8 |
| `Data.write(to:options:)` | iOS 2 |
| `.atomic` write option | iOS 2 |
