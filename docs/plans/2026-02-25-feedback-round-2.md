# Feedback Round 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add emoji "Faces" stamp category, fix stamp z-axis with a creation-order/always-on-top toggle, and move the grain-spread slider from crayon to chalk in the kid brush builder.

**Architecture:** Three independent changes. Task 1 (faces) is data-only. Task 2 (z-axis) refactors DrawingState from dual arrays to a unified DrawingElement list with a toggle. Task 3 (brush slider) is a small UI+render fix in KidBrushBuilderView and DrawingCanvasView.

**Tech Stack:** SwiftUI, iOS 15+, iPad-only

---

### Task 1: Add "Faces" stamp category

**Files:**
- Modify: `ColoringApp/Models.swift:220-238` (allStampCategories)
- Modify: `ColoringApp/StampsView.swift:12-17` (kidCategoryColors)
- Modify: `ColoringApp/KidContentView.swift:18-37` (stampSoundMap)

**Step 1: Add Faces category to allStampCategories**

In `Models.swift`, add a 5th entry to `allStampCategories` after the "Fun" category:

```swift
let allStampCategories: [StampCategory] = [
    StampCategory(name: "Animals", icon: "🐾", stamps: [
        "🐶","🐱","🐰","🦊","🐻","🐼","🐨","🐯",
        "🦁","🐮","🐷","🐸","🐵","🐔","🐧","🦆",
        "🐘","🦒","🦓","🦬","🐬","🐠","🦀","🐢"
    ]),
    StampCategory(name: "Insects", icon: "🦋", stamps: [
        "🦋","🐛","🐜","🐝","🪲","🐞","🦗","🕷️",
        "🪳","🦟","🪰","🪱","🦂","🐌","🦎","🐡"
    ]),
    StampCategory(name: "Plants", icon: "🌸", stamps: [
        "🌸","🌺","🌻","🌹","🌷","🌳","🌲","🌴",
        "🌵","🍀","🍁","🍃","🌿","🌱","🌾","🎋"
    ]),
    StampCategory(name: "Fun", icon: "⭐", stamps: [
        "⭐","🌈","☀️","🌙","❤️","🎈","🎀","🎁",
        "🏠","🚂","🚀","🦄","🍦","🍭","🎪","🎠"
    ]),
    StampCategory(name: "Faces", icon: "😀", stamps: [
        "😀","😁","😂","🤣","😄","😆","😊","😋",
        "😍","🥰","🤗","🥳","🤩","😎","😜","😢"
    ]),
]
```

**Step 2: Add kid-mode tab color for Faces**

In `StampsView.swift`, add a 5th color to `kidCategoryColors`:

```swift
private let kidCategoryColors: [Color] = [
    Color(r: 255, g: 180, b: 100),  // Animals — orange
    Color(r: 130, g: 200, b: 130),  // Insects — green
    Color(r: 255, g: 160, b: 190),  // Plants  — pink
    Color(r: 190, g: 160, b: 230),  // Fun     — purple
    Color(r: 255, g: 230, b: 100),  // Faces   — yellow
]
```

**Step 3: Add sound mappings for face emojis**

In `KidContentView.swift`, add entries to `stampSoundMap`:

```swift
    // Faces
    "😀":"Ha ha!", "😁":"Hee hee!", "😂":"Ha ha ha!", "🤣":"So funny!",
    "😄":"Yay!", "😆":"Hee hee hee!", "😊":"Aww!", "😋":"Yummy!",
    "😍":"So pretty!", "🥰":"Love love!", "🤗":"Hug!", "🥳":"Party time!",
    "🤩":"Wow!", "😎":"Cool!", "😜":"Silly!", "😢":"Aww!"
```

Add these lines right before the closing `]` of `stampSoundMap` (after line 36).

**Step 4: Commit**

```bash
git add ColoringApp/Models.swift ColoringApp/StampsView.swift ColoringApp/KidContentView.swift
git commit -m "feat: add Faces emoji stamp category with sound mappings"
```

---

### Task 2: Unified z-axis with creation-order / stamps-on-top toggle

This is the biggest change. It refactors `DrawingState` from separate `strokes`/`stamps` arrays into a unified `drawingElements` list, adds a toggle, updates persistence, and updates rendering.

**Files:**
- Modify: `ColoringApp/Models.swift:188-349` (DrawingElement enum, DrawingState refactor)
- Modify: `ColoringApp/DrawingCanvasView.swift:12-46` (rendering logic)
- Modify: `ColoringApp/DrawingPersistence.swift:104-110` (DrawingSnapshot + CodableDrawingElement)
- Modify: `ColoringApp/TopToolbarView.swift:63-100` (toggle button)
- Modify: `ColoringApp/KidContentView.swift:152-206` (KidTopToolbarView toggle)

#### Step 1: Add DrawingElement enum to Models.swift

Add this right before `// MARK: - Drawing State` (before line 240):

```swift
// MARK: - Unified Drawing Element

enum DrawingElement: Identifiable {
    case stroke(Stroke)
    case stamp(StampPlacement)

    var id: UUID {
        switch self {
        case .stroke(let s): return s.id
        case .stamp(let s):  return s.id
        }
    }
}
```

#### Step 2: Refactor DrawingState to use unified elements

Replace the drawing data and undo sections of `DrawingState` (lines 257-348). Key changes:

1. Replace `strokes`, `stamps`, `currentStroke` stored properties and `strokeHistory`/`stampHistory` with:

```swift
    // Drawing data — unified ordered list
    @Published var drawingElements: [DrawingElement] = []
    @Published var currentStroke: Stroke? = nil
    @Published var stampsAlwaysOnTop: Bool = false

    // Undo stack
    private var elementHistory: [[DrawingElement]] = []
```

2. Add computed properties so existing code that reads `strokes`/`stamps` still works:

```swift
    var strokes: [Stroke] {
        drawingElements.compactMap {
            if case .stroke(let s) = $0 { return s } else { return nil }
        }
    }

    var stamps: [StampPlacement] {
        drawingElements.compactMap {
            if case .stamp(let s) = $0 { return s } else { return nil }
        }
    }
```

3. Update `endStroke()`:

```swift
    func endStroke() {
        guard let stroke = currentStroke else { return }
        elementHistory.append(drawingElements)
        drawingElements.append(.stroke(stroke))
        currentStroke = nil
        persistDrawing()
    }
```

4. Update `placeStamp(at:)`:

```swift
    func placeStamp(at point: CGPoint) {
        elementHistory.append(drawingElements)
        drawingElements.append(.stamp(StampPlacement(
            emoji:    selectedStamp,
            location: point,
            size:     brushSize * 2.8,
            opacity:  Double(brushOpacity)
        )))
        persistDrawing()
    }
```

5. Update `removeStamp(id:)`:

```swift
    func removeStamp(id: UUID) {
        elementHistory.append(drawingElements)
        drawingElements.removeAll {
            if case .stamp(let s) = $0 { return s.id == id } else { return false }
        }
        persistDrawing()
    }
```

6. Update `undo()`:

```swift
    func undo() {
        if !elementHistory.isEmpty {
            drawingElements = elementHistory.removeLast()
        }
        persistDrawing()
    }
```

7. Update `clear()`:

```swift
    func clear() {
        elementHistory.append(drawingElements)
        drawingElements = []
        currentStroke = nil
        persistDrawing()
    }
```

8. Update `canUndo`:

```swift
    var canUndo: Bool { !elementHistory.isEmpty }
```

9. Update `persistDrawing()` — see Step 3 below.

10. Update `loadDrawing()` — see Step 3 below.

#### Step 3: Update persistence (DrawingPersistence.swift)

Add `CodableDrawingElement`:

```swift
// MARK: - Codable Drawing Element

enum CodableDrawingElement: Codable {
    case stroke(CodableStroke)
    case stamp(CodableStampPlacement)

    enum CodingKeys: String, CodingKey { case type, data }

    init(_ element: DrawingElement) {
        switch element {
        case .stroke(let s): self = .stroke(CodableStroke(s))
        case .stamp(let s):  self = .stamp(CodableStampPlacement(s))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stroke(let s):
            try c.encode("stroke", forKey: .type)
            try c.encode(s, forKey: .data)
        case .stamp(let s):
            try c.encode("stamp", forKey: .type)
            try c.encode(s, forKey: .data)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "stroke": self = .stroke(try c.decode(CodableStroke.self, forKey: .data))
        case "stamp":  self = .stamp(try c.decode(CodableStampPlacement.self, forKey: .data))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown element type: \(type)")
        }
    }

    var element: DrawingElement {
        switch self {
        case .stroke(let s): return .stroke(s.stroke)
        case .stamp(let s):  return .stamp(s.stampPlacement)
        }
    }
}
```

Update `DrawingSnapshot` with backward compat:

```swift
struct DrawingSnapshot: Codable {
    // New unified format
    let elements: [CodableDrawingElement]?
    // Legacy format (kept for backward compat decoding)
    let strokes: [CodableStroke]?
    let stamps: [CodableStampPlacement]?
    let backgroundColor: CodableColor

    // Encode always uses new format
    init(elements: [CodableDrawingElement], backgroundColor: CodableColor) {
        self.elements = elements
        self.strokes = nil
        self.stamps = nil
        self.backgroundColor = backgroundColor
    }

    // Decode handles both old and new
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = try c.decode(CodableColor.self, forKey: .backgroundColor)
        elements = try c.decodeIfPresent([CodableDrawingElement].self, forKey: .elements)
        strokes  = try c.decodeIfPresent([CodableStroke].self, forKey: .strokes)
        stamps   = try c.decodeIfPresent([CodableStampPlacement].self, forKey: .stamps)
    }

    /// Returns unified drawing elements — handles legacy and new format
    var drawingElements: [DrawingElement] {
        if let elements = elements {
            return elements.map { $0.element }
        }
        // Legacy: stamps first (old render order), then strokes
        var result: [DrawingElement] = []
        if let stamps = stamps {
            result += stamps.map { .stamp($0.stampPlacement) }
        }
        if let strokes = strokes {
            result += strokes.map { .stroke($0.stroke) }
        }
        return result
    }
}
```

Update `persistDrawing()` in `DrawingState`:

```swift
    func persistDrawing() {
        let snapshot = DrawingSnapshot(
            elements:        drawingElements.map { CodableDrawingElement($0) },
            backgroundColor: CodableColor(backgroundColor)
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: drawingFileURL, options: .atomic)
        }
    }
```

Update `loadDrawing()` in `DrawingState`:

```swift
    private func loadDrawing() {
        guard let data = try? Data(contentsOf: drawingFileURL),
              let snapshot = try? JSONDecoder().decode(DrawingSnapshot.self, from: data)
        else { return }
        drawingElements = snapshot.drawingElements
        backgroundColor = snapshot.backgroundColor.color
    }
```

#### Step 4: Update DrawingCanvasView rendering

Replace the Canvas body (lines 12-46) rendering section. The key change:

```swift
Canvas { ctx, size in
    // 1. Background fill
    ctx.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(state.backgroundColor)
    )

    if state.stampsAlwaysOnTop {
        // Stamps-on-top mode: all strokes first, then all stamps
        for element in state.drawingElements {
            if case .stroke(let stroke) = element {
                render(stroke: stroke, in: ctx)
            }
        }
        for element in state.drawingElements {
            if case .stamp(let stamp) = element {
                renderStamp(stamp, in: ctx)
            }
        }
    } else {
        // Creation-order mode: render in order
        for element in state.drawingElements {
            switch element {
            case .stroke(let stroke):
                render(stroke: stroke, in: ctx)
            case .stamp(let stamp):
                renderStamp(stamp, in: ctx)
            }
        }
    }

    // In-progress stroke (topmost)
    if let live = state.currentStroke {
        render(stroke: live, in: ctx)
    }
}
```

Extract the stamp rendering into a helper method on `DrawingCanvasView`:

```swift
private func renderStamp(_ stamp: StampPlacement, in ctx: GraphicsContext) {
    let fontSize = stamp.size * 0.72
    let rect = CGRect(
        x: stamp.location.x - stamp.size / 2,
        y: stamp.location.y - stamp.size / 2,
        width: stamp.size,
        height: stamp.size
    )
    ctx.drawLayer { layerCtx in
        layerCtx.opacity = stamp.opacity
        layerCtx.draw(
            Text(stamp.emoji).font(.system(size: fontSize)),
            in: rect
        )
    }
}
```

#### Step 5: Add toggle to TopToolbarView

In `TopToolbarView.swift`, add a toggle button between Eraser and Clear (or after Eraser). Insert after the Eraser block (after line 100):

```swift
            // Stamps layer toggle
            ToolbarButton(
                icon: state.stampsAlwaysOnTop ? "square.3.layers.3d.top.filled" : "square.3.layers.3d",
                label: state.stampsAlwaysOnTop ? "On Top" : "Mixed",
                color: .teal,
                disabled: false,
                action: { state.stampsAlwaysOnTop.toggle() }
            )
```

Note: `square.3.layers.3d.top.filled` and `square.3.layers.3d` are SF Symbols. If not available on iOS 15, fallback to `"square.stack.3d.up"` / `"square.stack.3d.up.fill"`.

#### Step 6: Add toggle to KidTopToolbarView

In `KidContentView.swift`, add a `KidToolbarButton` for the toggle in `KidTopToolbarView`. Insert after the Erase button (after line 169):

```swift
            KidToolbarButton(
                icon: state.stampsAlwaysOnTop ? "square.stack.3d.up.fill" : "square.stack.3d.up",
                label: state.stampsAlwaysOnTop ? "On Top" : "Mixed",
                color: .teal, disabled: false,
                isActive: state.stampsAlwaysOnTop
            ) {
                state.stampsAlwaysOnTop.toggle()
            }
```

#### Step 7: Commit

```bash
git add ColoringApp/Models.swift ColoringApp/DrawingCanvasView.swift ColoringApp/DrawingPersistence.swift ColoringApp/TopToolbarView.swift ColoringApp/KidContentView.swift
git commit -m "feat: unified z-axis with creation-order / stamps-on-top toggle"
```

---

### Task 3: Move grain-spread slider from crayon to chalk

**Files:**
- Modify: `ColoringApp/KidBrushBuilderView.swift:132-176` (slider UI)
- Modify: `ColoringApp/KidBrushBuilderView.swift:283-302` (save logic)
- Modify: `ColoringApp/KidBrushBuilderView.swift:247-263` (chalk preview)
- Modify: `ColoringApp/DrawingCanvasView.swift:267-288` (renderChalk)

#### Step 1: Move slider UI from crayon to chalk

In `KidBrushBuilderView.swift`, replace the contextual sliders section (lines 132-176):

```swift
            // ── Contextual Sliders ──
            VStack(spacing: 6) {
                if selectedTexture == .patternStamp {
                    Slider(value: $stampSpacing, in: 0.5...3.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("dense").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("spread").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                } else if selectedTexture == .chalk {
                    // Slider 1: soft ↔ bold
                    Slider(value: $intensity, in: 0.0...1.0)
                        .tint(.blue)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("soft").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("bold").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                    // Slider 2: tight ↔ spread grain
                    Slider(value: $grainSpread, in: 0.5...3.0)
                        .tint(.brown)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("tight grain").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("spread grain").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                } else {
                    Slider(value: $intensity, in: 0.0...1.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("soft").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("bold").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.top, 16)
```

Key change: the `.crayon` branch becomes the generic `else` branch (just soft/bold), and `.chalk` gets the 2-slider treatment that `.crayon` used to have.

#### Step 2: Fix save logic

In `KidBrushBuilderView.save()` (line 297-298), change `stampSpacing` assignment:

```swift
            stampSpacing: selectedTexture == .patternStamp ? stampSpacing
                        : selectedTexture == .chalk        ? grainSpread
                        : 1.0,
```

Change from `selectedTexture == .crayon ? grainSpread` to `selectedTexture == .chalk ? grainSpread`.

#### Step 3: Update chalk preview to use grainSpread

In `KidBrushBuilderView.renderPreview()`, chalk case (line 250), change:

```swift
        case .chalk:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            let cSpread = brushSize * 0.6 * grainSpread
```

Change `let cSpread = brushSize * 0.6` to `let cSpread = brushSize * 0.6 * grainSpread`.

#### Step 4: Update renderChalk in DrawingCanvasView

In `DrawingCanvasView.swift`, `renderChalk()` (line 271), change:

```swift
    private func renderChalk(_ stroke: Stroke, in ctx: GraphicsContext) {
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
        let spread = stroke.brushSize * (stroke.brush.isSystem ? 0.6 : 0.6 * stroke.brush.stampSpacing)
```

Change `let spread = stroke.brushSize * 0.6` to `let spread = stroke.brushSize * (stroke.brush.isSystem ? 0.6 : 0.6 * stroke.brush.stampSpacing)`.

#### Step 5: Commit

```bash
git add ColoringApp/KidBrushBuilderView.swift ColoringApp/DrawingCanvasView.swift
git commit -m "fix: move grain-spread slider from crayon to chalk in kid brush builder"
```

---

### Task 4: Build verification

**Step 1: Push and build on simulator**

```bash
git push
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

**Step 2: Fix any build errors**

If errors, fix and re-push. Common issues:
- SF Symbol names not available on iOS 15 — use fallback icons
- `DrawingSnapshot` Codable conformance — ensure `encode(to:)` is provided if auto-synthesis breaks

**Step 3: Final commit if fixes needed**

```bash
git add -A && git commit -m "fix: build errors from feedback round 2"
git push
```
