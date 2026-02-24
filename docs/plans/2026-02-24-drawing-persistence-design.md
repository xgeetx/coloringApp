# Drawing Persistence Design
**Date:** 2026-02-24
**Status:** Approved

## Goal

Persist the current drawing to disk so it survives hub navigation and app restarts. Always opens the last drawing. Clear also wipes the persisted state.

## Approach

Extend `DrawingState` to save/load a `DrawingSnapshot` as JSON in the app's Documents directory. No structural refactor needed — `ContentView` keeps its `@StateObject DrawingState`, which reloads the last drawing from disk on each `init()`.

---

## Data Model

`SwiftUI.Color` is not `Codable`, so we introduce `CodableColor` and Codable counterparts for the drawing types. These live in a new file `DrawingPersistence.swift`.

### New types (all in `DrawingPersistence.swift`)

```swift
struct CodableColor: Codable {
    let r, g, b, a: Double
    init(_ color: Color) { /* UIColor bridge */ }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

struct CodableStrokePoint: Codable {
    let x, y: Double
    init(_ p: StrokePoint) { x = p.location.x; y = p.location.y }
    var strokePoint: StrokePoint { StrokePoint(location: CGPoint(x: x, y: y)) }
}

struct CodableStroke: Codable {
    let points: [CodableStrokePoint]
    let color: CodableColor
    let brushSize: Double
    let brush: BrushDescriptor      // already Codable
    init(_ s: Stroke) { ... }
    var stroke: Stroke { Stroke(points: ..., color: color.color, brushSize: brushSize, brush: brush) }
}

struct CodableStampPlacement: Codable {
    let emoji: String
    let x, y, size: Double
    init(_ s: StampPlacement) { ... }
    var stampPlacement: StampPlacement { ... }
}

struct DrawingSnapshot: Codable {
    var strokes: [CodableStroke]
    var stamps: [CodableStampPlacement]
    var backgroundColor: CodableColor
}
```

---

## File Location

```
<Documents>/currentDrawing.json
```

Obtained via:
```swift
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("currentDrawing.json")
```

---

## DrawingState Changes (Models.swift)

### New private helpers

```swift
private var drawingFileURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("currentDrawing.json")
}

func persistDrawing() {
    let snapshot = DrawingSnapshot(
        strokes: strokes.map { CodableStroke($0) },
        stamps: stamps.map { CodableStampPlacement($0) },
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
    strokes = snapshot.strokes.map { $0.stroke }
    stamps = snapshot.stamps.map { $0.stampPlacement }
    backgroundColor = snapshot.backgroundColor.color
}
```

### Modified methods

- `loadFromUserDefaults()` renamed to `loadPersistedState()`, extended to call `loadDrawing()` at the end
- `endStroke()` — add `persistDrawing()` at end
- `placeStamp()` — add `persistDrawing()` at end
- `undo()` — add `persistDrawing()` at end
- `clear()` — add `persistDrawing()` at end (writes empty strokes/stamps, persisting the cleared state)

---

## Files Changed

| File | Change |
|------|--------|
| `ColoringApp/DrawingPersistence.swift` | **CREATE** — all Codable wrapper types + DrawingSnapshot |
| `ColoringApp/Models.swift` | Extend `DrawingState` with `drawingFileURL`, `persistDrawing()`, `loadDrawing()`; rename `loadFromUserDefaults` → `loadPersistedState`; add `persistDrawing()` calls to 4 mutation methods |
| `ColoringFun.xcodeproj/project.pbxproj` | Register `DrawingPersistence.swift` in Sources |

---

## Task IDs

- Task #22 — Create DrawingPersistence.swift
- Task #23 — Update Models.swift (DrawingState persistence hooks)
- Task #24 — Register DrawingPersistence.swift in project.pbxproj
- Task #25 — Push and verify on device
