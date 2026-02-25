# Brush Rendering Overhaul + Kid Mode Sliders — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Make crayon, marker, and chalk draw unmistakably differently on the canvas, and add size/opacity sliders to the kid mode top bar when a brush is active.

**Architecture:** All brush rendering changes are confined to `DrawingCanvasView.swift` (three private render functions). Slider changes are confined to `KidContentView.swift` (`KidTopToolbarView` + a new `KidSlider` component added to the same file). No new files, no pbxproj changes.

**Tech Stack:** SwiftUI Canvas API, iOS 15+, existing `deterministicJitter` PRNG.

---

## What Each Brush Should Feel Like After This Change

- **Crayon** — waxy, textured. Same 5 offset passes as now, but with a layer of random stipple dots scattered within the stroke width simulating paper grain showing through wax. Looks dense and rough.
- **Marker** — clean, saturated, zero texture. A wide very-transparent halo pre-pass (ink bleed) then a solid opaque pass on top. Looks bold and even — the cleanest of the three by far.
- **Chalk** — no stroke path at all. Pure particle cloud: 5 tiny dots scattered around each stroke point. Looks powdery, broken, airy — nothing like a line.

---

## Task 1: Rewrite `renderCrayon` — add stipple grain layer

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift` lines 114–145

### Step 1: Replace `renderCrayon`

Find and replace the entire function:

```swift
private func renderCrayon(_ stroke: Stroke, in ctx: GraphicsContext) {
    let opacityScale = stroke.brush.isSystem
        ? 1.0
        : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
    let offsets: [(CGFloat, CGFloat, Double)] = [
        (-2.5, -1.5, 0.50),
        (-1.0, -0.5, 0.65),
        ( 0.0,  0.0, 0.72),
        ( 1.0,  0.8, 0.60),
        ( 2.2,  1.5, 0.45),
    ]
    for (i, (dx, dy, opacity)) in offsets.enumerated() {
        var path = Path()
        let jitterX = deterministicJitter(index: i,       strokeHash: stroke.id.hashValue) * 1.5
        let jitterY = deterministicJitter(index: i + 100, strokeHash: stroke.id.hashValue) * 1.5
        let pts = stroke.points.map {
            CGPoint(x: $0.location.x + dx + jitterX, y: $0.location.y + dy + jitterY)
        }
        guard let first = pts.first else { continue }
        path.move(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(
            path,
            with: .color(stroke.color.opacity(min(opacity * opacityScale, 1.0))),
            style: StrokeStyle(
                lineWidth: stroke.brushSize * 0.85,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
    // Paper grain stipple — dots scattered within stroke width
    // Uses index range 500+ to avoid collision with pass jitter indices (0–4, 100–104)
    let spread = stroke.brushSize * 0.45
    let hash   = stroke.id.hashValue
    for (i, pt) in stroke.points.enumerated() where i % 2 == 0 {
        let si = i / 2
        let ox = (deterministicJitter(index: 500 + si * 4,     strokeHash: hash) * 2 - 1) * spread
        let oy = (deterministicJitter(index: 500 + si * 4 + 1, strokeHash: hash) * 2 - 1) * spread
        let r  =  0.5 + deterministicJitter(index: 500 + si * 4 + 2, strokeHash: hash) * 2.0
        let op =  0.04 + deterministicJitter(index: 500 + si * 4 + 3, strokeHash: hash) * 0.18
        let x  = pt.location.x + ox
        let y  = pt.location.y + oy
        ctx.fill(
            Ellipse().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
            with: .color(stroke.color.opacity(op))
        )
    }
}
```

**Why the `500+` offset?** The 5-pass loop uses jitter indices 0–4 and 100–104. The stipple starts at 500 to guarantee no hash collision with those.

**Why `i % 2 == 0`?** Sampling every other point keeps dot count reasonable for long strokes (50 points → 25 dot clusters) without sacrificing the grainy look.

### Step 2: Commit

```bash
git add ColoringApp/DrawingCanvasView.swift
git commit -m "feat: crayon stipple grain — paper texture dots along stroke path"
```

---

## Task 2: Rewrite `renderMarker` — halo + clean solid pass

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift` lines 147–175

### Step 1: Replace `renderMarker`

Find and replace the entire function:

```swift
private func renderMarker(_ stroke: Stroke, in ctx: GraphicsContext) {
    let opacityScale = stroke.brush.isSystem
        ? 1.0
        : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
    guard let first = stroke.points.first else { return }

    if stroke.points.count == 1 {
        // Dot: halo ring then solid fill
        let r = stroke.brushSize / 2
        ctx.fill(
            Ellipse().path(in: CGRect(x: first.location.x - r * 1.6,
                                      y: first.location.y - r * 1.6,
                                      width: stroke.brushSize * 1.6 * 2,
                                      height: stroke.brushSize * 1.6 * 2)),
            with: .color(stroke.color.opacity(0.08))
        )
        ctx.fill(
            Ellipse().path(in: CGRect(x: first.location.x - r,
                                      y: first.location.y - r,
                                      width: stroke.brushSize,
                                      height: stroke.brushSize)),
            with: .color(stroke.color.opacity(min(0.82 * opacityScale, 1.0)))
        )
        return
    }

    // Halo pass — wide, very transparent (ink bleed)
    var haloPath = Path()
    haloPath.move(to: first.location)
    for pt in stroke.points.dropFirst() { haloPath.addLine(to: pt.location) }
    ctx.stroke(haloPath,
               with: .color(stroke.color.opacity(0.08)),
               style: StrokeStyle(lineWidth: stroke.brushSize * 2.2,
                                  lineCap: .round, lineJoin: .round))

    // Solid pass — clean, saturated, no texture
    var path = Path()
    path.move(to: first.location)
    for pt in stroke.points.dropFirst() { path.addLine(to: pt.location) }
    ctx.stroke(path,
               with: .color(stroke.color.opacity(min(0.82 * opacityScale, 1.0))),
               style: StrokeStyle(lineWidth: stroke.brushSize * 1.5,
                                  lineCap: .round, lineJoin: .round))
}
```

**What changed:** Width scaled from `1.6` to `1.5` on the solid pass; a new halo pre-pass at `2.2×` width, opacity 0.08. No jitter, no grain — clean and even.

### Step 2: Commit

```bash
git add ColoringApp/DrawingCanvasView.swift
git commit -m "feat: marker halo + clean solid pass — ink bleed edge, no texture"
```

---

## Task 3: Rewrite `renderChalk` — pure particle cloud

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift` lines 200–222

### Step 1: Replace `renderChalk`

Find and replace the entire function:

```swift
private func renderChalk(_ stroke: Stroke, in ctx: GraphicsContext) {
    let opacityScale = stroke.brush.isSystem
        ? 1.0
        : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
    let spread = stroke.brushSize * 0.6
    let hash   = stroke.id.hashValue
    for (i, pt) in stroke.points.enumerated() {
        // 5 dots per point, deterministically scattered within spread radius
        for j in 0..<5 {
            let idx = i * 5 + j
            let ox  = (deterministicJitter(index: idx * 4,     strokeHash: hash) * 2 - 1) * spread
            let oy  = (deterministicJitter(index: idx * 4 + 1, strokeHash: hash) * 2 - 1) * spread
            let r   =  1.0 + deterministicJitter(index: idx * 4 + 2, strokeHash: hash) * 4.0
            let op  =  0.08 + deterministicJitter(index: idx * 4 + 3, strokeHash: hash) * 0.20
            let x   = pt.location.x + ox
            let y   = pt.location.y + oy
            ctx.fill(
                Ellipse().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(stroke.color.opacity(min(op * opacityScale, 1.0)))
            )
        }
    }
}
```

**What changed:** The entire function body is replaced. No `Path` is built; no `ctx.stroke` is called. Instead, every stroke point spawns 5 tiny circles within `brushSize × 0.6` radius. Dots vary from 1–5pt radius and 0.08–0.28 opacity — powdery and broken-looking, nothing like a line.

**Performance note:** 5 fill ops per point. For a 100-point stroke this is 500 fill calls, comparable to the old 5-pass stroke (5 × 100 = 500 path segment draws). Should be fine.

### Step 2: Commit

```bash
git add ColoringApp/DrawingCanvasView.swift
git commit -m "feat: chalk is now a pure particle cloud — no stroke path, just scattered dots"
```

---

## Task 4: Add Size + Opacity sliders to kid mode top bar

**Files:**
- Modify: `ColoringApp/KidContentView.swift`

The sliders live in the spacer zone between `[Erase]` and `[Clear]`. They are only shown when `!state.isStampMode && !state.isEraserMode` (i.e. a brush is active). When stamp or eraser mode is active the space is empty, as it is today.

### Step 1: Replace the `Spacer()` in `KidTopToolbarView.body`

Find:
```swift
            Spacer()

            KidToolbarButton(icon: "trash", label: "Clear", color: .red, disabled: false) {
```

Replace with:
```swift
            if !state.isStampMode && !state.isEraserMode {
                HStack(spacing: 20) {
                    KidSlider(label: "Size",
                              value: $state.brushSize,
                              range: 6...80,
                              color: .blue)
                    KidSlider(label: "Opacity",
                              value: $state.brushOpacity,
                              range: 0.2...1.0,
                              color: .purple)
                }
                .padding(.horizontal, 12)
            } else {
                Spacer()
            }

            KidToolbarButton(icon: "trash", label: "Clear", color: .red, disabled: false) {
```

### Step 2: Add `KidSlider` component after `KidToolbarButton`

After the closing `}` of `struct KidToolbarButton`, add:

```swift
struct KidSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Slider(value: $value, in: range)
                .tint(color)
                .onChange(of: value) { _, _ in }  // triggers re-render
        }
        .frame(maxWidth: 150)
    }
}
```

**Note on `@Binding var value: CGFloat`:** `DrawingState.brushSize` and `brushOpacity` are both `@Published var CGFloat`. `KidTopToolbarView` holds `@ObservedObject var state: DrawingState`, so `$state.brushSize` and `$state.brushOpacity` produce valid `Binding<CGFloat>`. No adapter needed.

**Note on persistence:** `brushOpacity` and `brushSize` are persisted via `state.persist()`. The sliders update the `@Published` vars in real time. For durability, `KidContentView` already calls `state.persist()` indirectly through brush selection. No additional wiring needed here — the values are live in memory and will be written on the next natural persist call.

### Step 3: Commit

```bash
git add ColoringApp/KidContentView.swift
git commit -m "feat: size + opacity sliders in kid mode top bar (brush mode only)"
```

---

## Task 5: Build and push

### Step 1: Push

```bash
git push origin main
```

### Step 2: SSH build on Mac

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`, no `error:` lines.

---

## Verification Checklist

- [ ] Crayon stroke has visible speckled grain texture embedded in the wax — looks rough compared to before
- [ ] Marker stroke looks clean and bold with soft bleed at edges — no grain, most saturated of the three
- [ ] Chalk leaves a cloud of dots, not a line — you can see through it, it looks powdery
- [ ] All three are unmistakably different at a glance
- [ ] Kid mode top bar: Size and Opacity sliders appear between Erase and Clear when a brush is active
- [ ] Sliders disappear (spacer returns) when Erase or Stamp mode is active
- [ ] Dragging the Size slider changes stroke width in real time on the canvas
- [ ] Dragging the Opacity slider changes stroke opacity in real time
- [ ] Both modes (parent + kid) have updated brush rendering
