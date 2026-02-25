# Wife Feedback Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Implement 11 UX improvements identified during first user-testing session on the physical iPad.

**Architecture:** Changes are spread across Models, DrawingCanvasView, TopToolbarView, ToolsView, StampsView, ColorPaletteView, and HubView. Most tasks are small and isolated. The opacity feature is the largest and touches 3 files. Tasks are ordered to resolve dependencies: model changes before rendering before UI.

**Tech Stack:** SwiftUI (iOS 15+), Canvas API for rendering, UserDefaults for lightweight persistence. No test target exists — each task verifies by building via `xcodebuild` over SSH.

**Build command (run after every task):**
```bash
ssh claude@192.168.50.251 "xcodebuild -project ~/Dev/coloringApp/ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected output: `** BUILD SUCCEEDED **`

**Workflow:** Edit files in WSL (`/home/geet/Claude/coloringApp/`), `git push`, then `git pull` on Mac before building.

```bash
# Pull on Mac after every push:
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
```

---

## Task 1: Hearts Brush — Uniform Size

**Files:**
- Modify: `ColoringApp/Models.swift:90`

**Step 1: Make the change**

In `Models.swift`, find the Hearts `BrushDescriptor` (line ~90). Change `sizeVariation` from `0.25` to `0.0`:

```swift
BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                name: "Hearts",   icon: "❤️", baseStyle: .patternStamp,
                patternShape: .heart, stampSpacing: 1.3, sizeVariation: 0.0, isSystem: true),
```

**Step 2: Build and verify**

```bash
git add ColoringApp/Models.swift && git commit -m "fix: hearts brush uniform size (sizeVariation 0.25 → 0.0)"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command above
```

---

## Task 2: Stamps — Auto-Select First Stamp on Category Change

**Files:**
- Modify: `ColoringApp/StampsView.swift`

**Step 1: Add `.onChange` to the category tab section**

In `StampsView.swift`, `StampsPanelView.body`, find the category tabs `ScrollView` (line ~16). After the `ScrollView` block and before the `Divider()`, add:

```swift
.onChange(of: selectedCategoryIndex) { newIndex in
    let category = allStampCategories[newIndex]
    if let first = category.stamps.first {
        state.selectedStamp = first
        state.isStampMode = true
    }
}
```

Attach this `.onChange` to the outer `VStack` (the one wrapping all content in `body`).

**Step 2: Build and verify**

```bash
git add ColoringApp/StampsView.swift && git commit -m "fix: auto-select first stamp when switching categories"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 3: Eraser — Hard Erase Only

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

**Context:** The eraser uses `BrushDescriptor.eraser` which has `baseStyle: .marker`. `renderMarker` draws at `opacity(0.72)`. We need eraser strokes to always render at full opacity regardless of any future `brushOpacity` setting.

**Step 1: Add eraser check at the top of `render(stroke:in:)`**

In `DrawingCanvasView.swift`, find `render(stroke:in:)` (line ~70). Add an early-exit eraser path before the switch:

```swift
private func render(stroke: Stroke, in ctx: GraphicsContext) {
    guard !stroke.points.isEmpty else { return }

    // Eraser always hard-erases at full opacity
    if stroke.brush.id == BrushDescriptor.eraser.id {
        renderHardErase(stroke, in: ctx)
        return
    }

    switch stroke.brush.baseStyle {
    case .crayon:       renderCrayon(stroke, in: ctx)
    case .marker:       renderMarker(stroke, in: ctx)
    case .chalk:        renderChalk(stroke, in: ctx)
    case .patternStamp: renderPatternStamp(stroke, in: ctx)
    }
}
```

**Step 2: Add `renderHardErase` function**

Add after `renderMarker`:

```swift
private func renderHardErase(_ stroke: Stroke, in ctx: GraphicsContext) {
    var path = Path()
    guard let first = stroke.points.first else { return }
    path.move(to: first.location)

    if stroke.points.count == 1 {
        let r = stroke.brushSize / 2
        let rect = CGRect(x: first.location.x - r, y: first.location.y - r,
                          width: stroke.brushSize, height: stroke.brushSize)
        ctx.fill(Ellipse().path(in: rect), with: .color(stroke.color.opacity(1.0)))
        return
    }

    for pt in stroke.points.dropFirst() {
        path.addLine(to: pt.location)
    }
    ctx.stroke(
        path,
        with: .color(stroke.color.opacity(1.0)),
        style: StrokeStyle(lineWidth: stroke.brushSize * 1.6, lineCap: .round, lineJoin: .round)
    )
}
```

**Step 3: Build and verify**

```bash
git add ColoringApp/DrawingCanvasView.swift && git commit -m "fix: eraser always hard-erases at full opacity"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 4: Eraser — Move to Top Toolbar

**Files:**
- Modify: `ColoringApp/TopToolbarView.swift`
- Modify: `ColoringApp/ToolsView.swift`

**Step 1: Add eraser button to `TopToolbarView`**

In `TopToolbarView.swift`, in `body`, after the Clear button's `.confirmationDialog`, add:

```swift
// Eraser
ToolbarButton(
    icon: "eraser.fill",
    label: "Eraser",
    color: .orange,
    disabled: false,
    action: {
        state.isEraserMode.toggle()
        if state.isEraserMode { state.isStampMode = false }
    }
)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(state.isEraserMode ? Color.orange : Color.clear, lineWidth: 2)
)
```

**Step 2: Remove eraser from `ToolsView`**

In `ToolsView.swift`, find and delete the eraser `BrushDescriptorButton` block (lines ~41–50):

```swift
// DELETE this entire block:
// Eraser
BrushDescriptorButton(
    icon: "⬜",
    label: "Eraser",
    isSelected: state.isEraserMode,
    onTap: {
        state.isEraserMode = true
        state.isStampMode  = false
    }
)
```

**Step 3: Build and verify**

```bash
git add ColoringApp/TopToolbarView.swift ColoringApp/ToolsView.swift && git commit -m "feat: move eraser to top toolbar with eraser.fill icon"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 5: Crayon — More Distinct Texture

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

**Context:** Current crayon is 3 passes at low opacity offsets. Enhance to 5 passes with more visible texture and slight jitter per point.

**Step 1: Replace `renderCrayon` entirely**

Find `renderCrayon` (line ~80) and replace the whole function:

```swift
private func renderCrayon(_ stroke: Stroke, in ctx: GraphicsContext) {
    // 5 passes: offset + varying opacity creates wax texture
    let offsets: [(CGFloat, CGFloat, Double)] = [
        (-2.5, -1.5, 0.50),
        (-1.0, -0.5, 0.65),
        ( 0.0,  0.0, 0.72),
        ( 1.0,  0.8, 0.60),
        ( 2.2,  1.5, 0.45),
    ]
    for (i, (dx, dy, opacity)) in offsets.enumerated() {
        var path = Path()
        // Jitter each pass slightly using deterministic noise
        let jitter = deterministicJitter(index: i, strokeHash: stroke.id.hashValue) * 1.5
        let pts = stroke.points.map {
            CGPoint(x: $0.location.x + dx + jitter, y: $0.location.y + dy + jitter)
        }
        guard let first = pts.first else { continue }
        path.move(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(
            path,
            with: .color(stroke.color.opacity(opacity)),
            style: StrokeStyle(
                lineWidth: stroke.brushSize * 0.85,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}
```

**Step 2: Build and verify**

```bash
git add ColoringApp/DrawingCanvasView.swift && git commit -m "feat: enhance crayon texture with 5-pass rendering"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 6: Opacity — Model & Persistence

**Files:**
- Modify: `ColoringApp/Models.swift`
- Modify: `ColoringApp/DrawingPersistence.swift`

**Step 1: Add `opacity` to `Stroke`**

In `Models.swift`, find `struct Stroke` (line ~116). Add `opacity`:

```swift
struct Stroke: Identifiable {
    let id = UUID()
    var points: [StrokePoint]
    let color: Color
    let brushSize: CGFloat
    let brush: BrushDescriptor
    let opacity: CGFloat          // ← add this line
}
```

**Step 2: Add `brushOpacity` to `DrawingState`**

In `DrawingState` (line ~162), add to the active settings block:

```swift
@Published var brushOpacity: CGFloat = 1.0
```

And in `loadPersistedState()`, after the slot assignments block:

```swift
brushOpacity = CGFloat(UserDefaults.standard.double(forKey: "brushOpacity").clamped(to: 0.1...1.0))
if brushOpacity == 0.0 { brushOpacity = 1.0 } // handle missing key
```

And in `persist()`, add:

```swift
UserDefaults.standard.set(Double(brushOpacity), forKey: "brushOpacity")
```

**Step 3: Update `beginStroke` to pass opacity**

In `beginStroke(at:)` (line ~210):

```swift
func beginStroke(at point: CGPoint) {
    let brush   = isEraserMode ? BrushDescriptor.eraser : selectedBrush
    let color   = isEraserMode ? backgroundColor : selectedColor
    let opacity = isEraserMode ? 1.0 : brushOpacity   // eraser always 1.0
    currentStroke = Stroke(
        points:    [StrokePoint(location: point)],
        color:     color,
        brushSize: brushSize,
        brush:     brush,
        opacity:   opacity
    )
}
```

**Step 4: Add `CGFloat.clamped` helper**

At the bottom of `Models.swift`, add:

```swift
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

**Step 5: Update `CodableStroke` in `DrawingPersistence.swift`**

Add `opacity` field:

```swift
struct CodableStroke: Codable {
    let points: [CodableStrokePoint]
    let color: CodableColor
    let brushSize: Double
    let brush: BrushDescriptor
    let opacity: Double            // ← add

    init(_ stroke: Stroke) {
        points    = stroke.points.map { CodableStrokePoint($0) }
        color     = CodableColor(stroke.color)
        brushSize = Double(stroke.brushSize)
        brush     = stroke.brush
        opacity   = Double(stroke.opacity)   // ← add
    }

    var stroke: Stroke {
        Stroke(
            points:    points.map { $0.strokePoint },
            color:     color.color,
            brushSize: CGFloat(brushSize),
            brush:     brush,
            opacity:   CGFloat(opacity)       // ← add
        )
    }
}
```

**Step 6: Build and verify**

```bash
git add ColoringApp/Models.swift ColoringApp/DrawingPersistence.swift && git commit -m "feat: add per-stroke opacity to model and persistence"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 7: Opacity — Canvas Rendering

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

**Context:** Each render function receives a `Stroke` which now carries `stroke.opacity`. Wrap each render call in a `drawLayer` that applies the stroke opacity.

**Step 1: Wrap render calls in `render(stroke:in:)` with opacity layer**

Replace the `render(stroke:in:)` function:

```swift
private func render(stroke: Stroke, in ctx: GraphicsContext) {
    guard !stroke.points.isEmpty else { return }

    // Eraser always hard-erases at full opacity (Task 3)
    if stroke.brush.id == BrushDescriptor.eraser.id {
        renderHardErase(stroke, in: ctx)
        return
    }

    // Apply per-stroke opacity via a composited layer
    ctx.drawLayer { layerCtx in
        layerCtx.opacity = stroke.opacity
        switch stroke.brush.baseStyle {
        case .crayon:       renderCrayon(stroke, in: layerCtx)
        case .marker:       renderMarker(stroke, in: layerCtx)
        case .chalk:        renderChalk(stroke, in: layerCtx)
        case .patternStamp: renderPatternStamp(stroke, in: layerCtx)
        }
    }
}
```

**Step 2: Build and verify**

```bash
git add ColoringApp/DrawingCanvasView.swift && git commit -m "feat: apply per-stroke opacity in canvas rendering"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 8: Opacity — UI Slider in ToolsView

**Files:**
- Modify: `ColoringApp/ToolsView.swift`

**Step 1: Add opacity slider below size picker**

In `BrushToolsView.body`, find the Size Picker `VStack` block (line ~88). After its closing brace and before `Spacer()`, add:

```swift
Divider()

// ── Opacity ──
VStack(spacing: 8) {
    HStack {
        Text("Opacity")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
        Spacer()
        Text("\(Int(state.brushOpacity * 100))%")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
    }
    Slider(value: $state.brushOpacity, in: 0.1...1.0, step: 0.05)
        .tint(.purple)
        .onChange(of: state.brushOpacity) { _ in state.persist() }

    // Preview swatch
    RoundedRectangle(cornerRadius: 8)
        .fill(state.selectedColor.opacity(state.brushOpacity))
        .frame(height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        )
}
```

Note: `state.persist()` needs to be `internal` (not `private`) — update in `Models.swift`:

```swift
// Change: private func persist() → func persist()
func persist() {
```

**Step 2: Build and verify**

```bash
git add ColoringApp/ToolsView.swift ColoringApp/Models.swift && git commit -m "feat: add opacity slider to tools panel"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 9: Background — Expanded Swatches

**Files:**
- Modify: `ColoringApp/TopToolbarView.swift`

**Step 1: Replace `bgColors` array in `BackgroundColorPickerView`**

Find `private let bgColors` (line ~138) and replace the entire array with 24 swatches plus a custom `ColorPicker`. First, update `bgColors`:

```swift
private let bgColors: [(String, Color)] = [
    // Neutrals
    ("Cream",      Color(r: 255, g: 250, b: 235)),
    ("White",      Color(r: 255, g: 255, b: 255)),
    ("Pearl",      Color(r: 240, g: 235, b: 220)),
    // Pastels
    ("Sky",        Color(r: 204, g: 229, b: 255)),
    ("Mint",       Color(r: 204, g: 255, b: 229)),
    ("Peach",      Color(r: 255, g: 220, b: 200)),
    ("Lavender",   Color(r: 230, g: 210, b: 255)),
    ("Lemon",      Color(r: 255, g: 255, b: 200)),
    ("Rose",       Color(r: 255, g: 210, b: 220)),
    ("Baby Blue",  Color(r: 180, g: 220, b: 255)),
    ("Honeydew",   Color(r: 210, g: 255, b: 210)),
    ("Blush",      Color(r: 255, g: 200, b: 210)),
    // Brights
    ("Sunny",      Color(r: 255, g: 240, b: 100)),
    ("Coral",      Color(r: 255, g: 160, b: 130)),
    ("Aqua",       Color(r: 130, g: 220, b: 220)),
    ("Lilac",      Color(r: 200, g: 170, b: 255)),
    // Darks
    ("Slate",      Color(r: 80,  g: 100, b: 130)),
    ("Forest",     Color(r: 40,  g: 80,  b: 60)),
    ("Midnight",   Color(r: 20,  g: 25,  b: 60)),
    ("Charcoal",   Color(r: 55,  g: 55,  b: 65)),
    ("Black",      Color(r: 20,  g: 20,  b: 20)),
    // Warm darks
    ("Mocha",      Color(r: 80,  g: 50,  b: 30)),
    ("Burgundy",   Color(r: 90,  g: 20,  b: 40)),
    ("Dark Teal",  Color(r: 20,  g: 80,  b: 80)),
]
```

**Step 2: Update grid layout and add custom `ColorPicker`**

Replace the `LazyVGrid` section in `BackgroundColorPickerView.body`:

```swift
ScrollView {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
        ForEach(bgColors, id: \.0) { name, color in
            Button {
                state.backgroundColor = color
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().strokeBorder(
                                state.backgroundColor == color ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: state.backgroundColor == color ? 3 : 1
                            )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 3)
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }

        // Custom color picker
        VStack(spacing: 4) {
            ColorPicker("", selection: $state.backgroundColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 48, height: 48)
            Text("Custom")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
}
```

Also update the frame width to accommodate 5 columns × 24 items:

```swift
.frame(width: 340, height: 420)  // was: .frame(width: 340)
```

**Step 3: Build and verify**

```bash
git add ColoringApp/TopToolbarView.swift && git commit -m "feat: expand background swatches to 24 colors + custom ColorPicker"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 10: Color Palette — Add System ColorPicker

**Files:**
- Modify: `ColoringApp/ColorPaletteView.swift`

**Step 1: Read the current file**

Read `ColoringApp/ColorPaletteView.swift` to understand the current swatch layout before editing.

**Step 2: Add `ColorPicker` as final item in palette HStack**

The palette renders `CrayolaColor.palette` swatches in an `HStack`. Add a `ColorPicker` after the `ForEach`:

```swift
// After the ForEach of Crayola swatches, add:
ColorPicker("", selection: Binding(
    get: { state.selectedColor },
    set: { newColor in
        state.selectedColor = newColor
        state.isEraserMode  = false
        state.isStampMode   = false
    }
), supportsOpacity: false)
.labelsHidden()
.frame(width: 36, height: 36)
.padding(.horizontal, 4)
```

**Step 3: Build and verify**

```bash
git add ColoringApp/ColorPaletteView.swift && git commit -m "feat: add system ColorPicker to color palette bar"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 11: Pinch Gesture — Resize Brush

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

**Context:** Add a `MagnificationGesture` running simultaneously with the existing `DragGesture`. Track scale delta between updates to incrementally adjust `brushSize`. Clamp to `[6, 80]`.

**Step 1: Add magnification state and gesture to `DrawingCanvasView`**

Add a state variable for tracking the last scale:

```swift
@State private var lastMagnification: CGFloat = 1.0
```

**Step 2: Replace `.gesture(drawGesture)` with simultaneous gestures**

In `body`, replace:
```swift
.gesture(drawGesture)
```

With:
```swift
.gesture(drawGesture.simultaneously(with: pinchGesture))
```

**Step 3: Add `pinchGesture` computed property**

After `drawGesture`, add:

```swift
private var pinchGesture: some Gesture {
    MagnificationGesture()
        .onChanged { scale in
            let delta = scale / lastMagnification
            lastMagnification = scale
            state.brushSize = (state.brushSize * delta).clamped(to: 6...80)
        }
        .onEnded { _ in
            lastMagnification = 1.0
        }
}
```

**Step 4: Build and verify**

```bash
git add ColoringApp/DrawingCanvasView.swift && git commit -m "feat: pinch gesture resizes brush size"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 12: Hub — Triple-Tap to Rename Title

**Files:**
- Modify: `ColoringApp/HubView.swift`

**Step 1: Add state for hub title and rename alert**

In `HubView`, add:

```swift
@State private var hubTitle: String = UserDefaults.standard.string(forKey: "hubTitle") ?? "Triple Tap here to change Name"
@State private var showRenameAlert = false
@State private var pendingTitle = ""
```

**Step 2: Replace the static title `Text` with a tappable version**

Find:
```swift
Text("Kids Fun Zone")
    .font(.system(size: 44, weight: .bold, design: .rounded))
    .foregroundStyle(
        LinearGradient(
            colors: [.red, .orange, .yellow, .green, .blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
```

Replace with:
```swift
Text(hubTitle)
    .font(.system(size: 44, weight: .bold, design: .rounded))
    .foregroundStyle(
        LinearGradient(
            colors: [.red, .orange, .yellow, .green, .blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
    .onTapGesture(count: 3) {
        pendingTitle = hubTitle == "Triple Tap here to change Name" ? "" : hubTitle
        showRenameAlert = true
    }
```

**Step 3: Add the rename alert**

After `.fullScreenCover(item: $activeApp)`, add:

```swift
.alert("Name Your Zone", isPresented: $showRenameAlert) {
    TextField("Enter a name", text: $pendingTitle)
    Button("Save") {
        let trimmed = pendingTitle.trimmingCharacters(in: .whitespaces)
        hubTitle = trimmed.isEmpty ? "Triple Tap here to change Name" : trimmed
        UserDefaults.standard.set(hubTitle, forKey: "hubTitle")
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Triple-tap the title any time to change it.")
}
```

**Step 4: Build and verify**

```bash
git add ColoringApp/HubView.swift && git commit -m "feat: triple-tap hub title to rename, persisted to UserDefaults"
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull"
# run build command
```

---

## Task 13: Final Push and Smoke Test

**Step 1: Verify clean build**

```bash
ssh claude@192.168.50.251 "xcodebuild -project ~/Dev/coloringApp/ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|warning:|BUILD)'"
```

**Step 2: Confirm all 12 tasks are complete**

- [ ] Hearts brush uniform size
- [ ] Stamps auto-select first on category change
- [ ] Eraser hard erase only
- [ ] Eraser in top toolbar with `eraser.fill` icon
- [ ] Crayon 5-pass enhanced texture
- [ ] `Stroke.opacity` + `DrawingState.brushOpacity` in model
- [ ] Per-stroke opacity applied in canvas rendering
- [ ] Opacity slider in tools panel with preview swatch
- [ ] 24 background swatches + custom ColorPicker
- [ ] System ColorPicker in palette bar
- [ ] Pinch gesture resizes brush
- [ ] Triple-tap hub title to rename

**Step 3: Push final state**

```bash
git push
```
