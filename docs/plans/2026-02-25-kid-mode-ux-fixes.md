# Kid Mode UX Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Fix four Kid Mode issues: brush strip shows emoji icons instead of texture previews, brush builder creates a brush but doesn't select it, brush builder has shape picker instead of texture designer, and portrait mode layout collapses.

**Architecture:** KidBrushPreview (new Canvas-based view in KidContentView.swift) replaces emoji icons throughout. KidBrushBuilderView is redesigned from shape-stamping to texture selection. PatternShape gains a `path(center:size:)` method to eliminate three copies of identical shape math. sizeVariation field (already on BrushDescriptor) is wired into renderCrayon/renderChalk/renderMarker for non-system brushes only.

**Tech Stack:** SwiftUI, iOS 15+, no new files, no pbxproj changes.

---

## Task 1: Add `PatternShape.path(center:size:)` and clean up shape helpers

**Why:** DrawingCanvasView, KidBrushBuilderView, and the upcoming KidBrushPreview all need to render the same shape paths. Currently each has its own copy. Consolidate into the model.

**Files:**
- Modify: `ColoringApp/Models.swift` — add `path(center:size:)` to `PatternShape`
- Modify: `ColoringApp/DrawingCanvasView.swift` — replace `pathForShape(_:center:size:)` body + remove private helpers
- Modify: `ColoringApp/KidBrushBuilderView.swift` — remove `kidShapePath` and `makeStar` helpers

### Step 1: Add `path(center:size:)` to `PatternShape` in Models.swift

In `Models.swift`, directly after the `var displayName: String` line in `PatternShape`, add:

```swift
    func path(center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch self {
        case .star:
            var p = Path()
            let total = 10
            for i in 0..<total {
                let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
                let rr: CGFloat = i % 2 == 0 ? r : r * 0.42
                let x = center.x + rr * CGFloat(cos(angle))
                let y = center.y + rr * CGFloat(sin(angle))
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else       { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            p.closeSubpath()
            return p
        case .dot, .circle:
            return Ellipse().path(in: CGRect(x: center.x - r, y: center.y - r,
                                             width: size, height: size))
        case .square:
            return Rectangle().path(in: CGRect(x: center.x - r, y: center.y - r,
                                               width: size, height: size))
        case .diamond:
            var p = Path()
            p.move(to:    CGPoint(x: center.x,     y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y))
            p.addLine(to: CGPoint(x: center.x,     y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y))
            p.closeSubpath()
            return p
        case .heart:
            let w = size, h = size
            let x = center.x - w / 2, y = center.y - h / 2
            var p = Path()
            p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85))
            p.addCurve(to: CGPoint(x: x, y: y + h * 0.35),
                       control1: CGPoint(x: x + w * 0.1, y: y + h * 0.70),
                       control2: CGPoint(x: x, y: y + h * 0.50))
            p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.25),
                     radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.25),
                     radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85),
                       control1: CGPoint(x: x + w, y: y + h * 0.50),
                       control2: CGPoint(x: x + w * 0.9, y: y + h * 0.70))
            p.closeSubpath()
            return p
        case .flower:
            var p = Path()
            let petalR = size * 0.28
            let orbit  = size * 0.24
            for i in 0..<6 {
                let angle = Double(i) / 6.0 * 2 * .pi
                let cx = center.x + CGFloat(cos(angle)) * orbit
                let cy = center.y + CGFloat(sin(angle)) * orbit
                p.addEllipse(in: CGRect(x: cx - petalR, y: cy - petalR,
                                        width: petalR * 2, height: petalR * 2))
            }
            let cr = petalR * 0.6
            p.addEllipse(in: CGRect(x: center.x - cr, y: center.y - cr,
                                    width: cr * 2, height: cr * 2))
            return p
        case .triangle:
            var p = Path()
            p.move(to:    CGPoint(x: center.x,     y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y + r))
            p.closeSubpath()
            return p
        }
    }
```

### Step 2: Update DrawingCanvasView to use `PatternShape.path`

In `DrawingCanvasView.swift`, replace the entire `pathForShape(_:center:size:)` method body with a one-liner, and delete the private helpers `makeStar`, `makeDiamond`, `makeTriangle`, `makeHeart`, `makeFlower`.

Replace:
```swift
    private func pathForShape(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch shape {
        case .star:
            return makeStar(center: center, outerR: r, innerR: r * 0.42, points: 5)
        // ... all the cases ...
        }
    }
```

With:
```swift
    private func pathForShape(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
        shape.path(center: center, size: size)
    }
```

Then delete the five private helpers at the bottom of DrawingCanvasView: `makeStar`, `makeDiamond`, `makeTriangle`, `makeHeart`, `makeFlower`.

### Step 3: Remove duplicate helpers from KidBrushBuilderView

In `KidBrushBuilderView.swift`, delete `kidShapePath(_:center:size:)` and `makeStar(center:outerR:innerR:points:)` (lines 174–248). The live preview canvas body currently calls `kidShapePath`; replace each call site with `shape.path(center:, size:)`.

Find this in the Canvas body:
```swift
let path = kidShapePath(selectedShape, center: pt, size: brushSize)
```
Replace with:
```swift
let path = selectedShape.path(center: pt, size: brushSize)
```

### Step 4: Build to confirm no regressions

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```
Expected: `BUILD SUCCEEDED`

### Step 5: Commit

```bash
git add ColoringApp/Models.swift ColoringApp/DrawingCanvasView.swift ColoringApp/KidBrushBuilderView.swift
git commit -m "refactor: move shape path math to PatternShape.path(center:size:)"
```

---

## Task 2: Fix portrait layout collapse in KidContentView

**Why:** The canvas `ZStack` has no explicit frame, and the main `HStack` has no vertical size constraints. In portrait mode SwiftUI gives the canvas zero height.

**Files:**
- Modify: `ColoringApp/KidContentView.swift`

### Step 1: Fix the main HStack and canvas ZStack

In `KidContentView.body`, find the main `HStack(alignment: .top, spacing: 8)` block (lines ~42–91). Add `.frame(maxHeight: .infinity)` to it, and add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to the canvas `ZStack`.

Before:
```swift
                // ── Main Row: Brush Strip | Canvas | Stamp Grid ──
                HStack(alignment: .top, spacing: 8) {

                    // Left: texture brushes
                    KidBrushStripView(
                        state: state,
                        brushes: textureBrushes,
                        onBuildBrush: { showKidBuilder = true }
                    )
                    .frame(width: 84)

                    // Centre: canvas
                    ZStack {
```

After:
```swift
                // ── Main Row: Brush Strip | Canvas | Stamp Grid ──
                HStack(alignment: .top, spacing: 8) {

                    // Left: texture brushes
                    KidBrushStripView(
                        state: state,
                        brushes: textureBrushes,
                        onBuildBrush: { showKidBuilder = true }
                    )
                    .frame(width: 84)

                    // Centre: canvas
                    ZStack {
```

And find the closing of the canvas ZStack — immediately after `.shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)` and before the stamp banner, add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to the `DrawingCanvasView`:

The `DrawingCanvasView` line:
```swift
                        DrawingCanvasView(state: state)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(...)
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
```

Becomes:
```swift
                        DrawingCanvasView(state: state)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(...)
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
```

And add `.frame(maxHeight: .infinity)` to the HStack after its `.padding(.horizontal, 12)`:
```swift
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
```

### Step 2: Commit

```bash
git add ColoringApp/KidContentView.swift
git commit -m "fix: portrait layout - canvas and HStack fill available vertical space"
```

---

## Task 3: Add KidBrushPreview + update KidBrushButton

**Why:** Brush buttons show emoji (🖍️, 🖊️, 🩫, ✨) which don't communicate texture. Replace with a mini Canvas showing an actual stroke rendered in that brush's style.

**Files:**
- Modify: `ColoringApp/KidContentView.swift`

### Step 1: Add `KidBrushPreview` struct

Add this new struct ABOVE `#Preview` at the bottom of `KidContentView.swift` (after the `kidDragIndicator` extension):

```swift
// MARK: - Kid Brush Texture Preview

struct KidBrushPreview: View {
    let brush: BrushDescriptor
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let pts = makeWave(in: size)
            let sz: CGFloat = size.height * 0.38
            let scale = brush.isSystem ? 1.0 : Double((0.4 + brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
            switch brush.baseStyle {
            case .crayon:  drawCrayon(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .marker:  drawMarker(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .chalk:   drawChalk(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .patternStamp: drawStamps(ctx: ctx, pts: pts, sz: sz)
            }
        }
    }

    private func makeWave(in size: CGSize) -> [CGPoint] {
        (0..<30).map { i in
            let t = CGFloat(i) / 29
            return CGPoint(
                x: 6 + t * (size.width - 12),
                y: size.height / 2 + sin(t * .pi * 2.5) * (size.height * 0.22)
            )
        }
    }

    private func drawCrayon(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        let passes: [(CGFloat, CGFloat, Double)] = [(-1.5,-1.0,0.50),(0,0,0.65),(1.5,1.0,0.45)]
        for (dx, dy, op) in passes {
            var path = Path()
            let shifted = pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            guard let f = shifted.first else { continue }
            path.move(to: f)
            shifted.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(op * scale, 1.0))),
                       style: StrokeStyle(lineWidth: sz * 0.85, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawMarker(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        var path = Path()
        guard let f = pts.first else { return }
        path.move(to: f)
        pts.dropFirst().forEach { path.addLine(to: $0) }
        ctx.stroke(path, with: .color(color.opacity(min(0.72 * scale, 1.0))),
                   style: StrokeStyle(lineWidth: sz * 1.6, lineCap: .round, lineJoin: .round))
    }

    private func drawChalk(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        let passes: [(CGFloat, CGFloat, Double)] = [(-1.5,-1.0,0.30),(0,0,0.38),(1.2,0.8,0.28)]
        for (dx, dy, op) in passes {
            var path = Path()
            let shifted = pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            guard let f = shifted.first else { continue }
            path.move(to: f)
            shifted.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(op * scale, 1.0))),
                       style: StrokeStyle(lineWidth: sz * 0.65, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawStamps(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat) {
        let shape = brush.patternShape ?? .star
        let spacing = brush.stampSpacing * sz
        var last: CGPoint? = nil
        for pt in pts {
            if let l = last, hypot(pt.x - l.x, pt.y - l.y) < spacing { continue }
            last = pt
            ctx.fill(shape.path(center: pt, size: sz), with: .color(color))
        }
    }
}
```

### Step 2: Update `KidBrushButton` to use `KidBrushPreview`

Replace the `KidBrushButton` struct body (lines ~262–284 in the original):

Old `KidBrushButton`:
```swift
struct KidBrushButton: View {
    let brush: BrushDescriptor
    let isSelected: Bool
    let onTap: () -> Void
```

New `KidBrushButton` — add `color: Color` param and replace the emoji `Text(brush.icon)` with `KidBrushPreview`:

```swift
struct KidBrushButton: View {
    let brush: BrushDescriptor
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                KidBrushPreview(brush: brush, color: color)
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                Text(brush.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.white.opacity(0.7))
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : .clear,
                            radius: 6)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}
```

### Step 3: Update `KidBrushStripView` to pass `state.selectedColor`

In `KidBrushStripView.body`, the `ForEach` creates `KidBrushButton`. Add `color: state.selectedColor`:

Old:
```swift
                    KidBrushButton(
                        brush: brush,
                        isSelected: !state.isStampMode && !state.isEraserMode
                                    && state.selectedBrush.id == brush.id
                    ) {
```

New:
```swift
                    KidBrushButton(
                        brush: brush,
                        isSelected: !state.isStampMode && !state.isEraserMode
                                    && state.selectedBrush.id == brush.id,
                        color: state.selectedColor
                    ) {
```

### Step 4: Commit

```bash
git add ColoringApp/KidContentView.swift
git commit -m "feat: replace emoji brush icons with live texture previews in kid mode"
```

---

## Task 4: Wire `sizeVariation` into DrawingCanvasView texture renders

**Why:** User-created texture brushes will carry a `sizeVariation` value (0.0=soft, 0.5=normal, 1.0=bold). The render functions currently ignore it for crayon/marker/chalk. System brushes must remain visually unchanged.

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

### Step 1: Update `renderCrayon`

Add `opacityScale` computation at the top of the function and multiply each pass opacity by it:

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
    }
```

### Step 2: Update `renderMarker`

```swift
    private func renderMarker(_ stroke: Stroke, in ctx: GraphicsContext) {
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
        var path = Path()
        guard let first = stroke.points.first else { return }
        path.move(to: first.location)

        if stroke.points.count == 1 {
            let r = stroke.brushSize / 2
            let rect = CGRect(x: first.location.x - r, y: first.location.y - r,
                              width: stroke.brushSize, height: stroke.brushSize)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(stroke.color.opacity(min(0.75 * opacityScale, 1.0))))
            return
        }

        for pt in stroke.points.dropFirst() {
            path.addLine(to: pt.location)
        }
        ctx.stroke(
            path,
            with: .color(stroke.color.opacity(min(0.72 * opacityScale, 1.0))),
            style: StrokeStyle(
                lineWidth: stroke.brushSize * 1.6,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
```

### Step 3: Update `renderChalk`

```swift
    private func renderChalk(_ stroke: Stroke, in ctx: GraphicsContext) {
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
        let offsets: [(CGFloat, CGFloat, Double)] = [
            (-2.0, -1.5, 0.30),
            (-0.8, -0.5, 0.38),
            ( 0.0,  0.0, 0.42),
            ( 0.7,  1.0, 0.33),
            ( 1.8, -0.5, 0.28),
        ]
        for (dx, dy, opacity) in offsets {
            var path = Path()
            let pts = stroke.points.map { CGPoint(x: $0.location.x + dx, y: $0.location.y + dy) }
            guard let first = pts.first else { continue }
            path.move(to: first)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            ctx.stroke(path,
                       with: .color(stroke.color.opacity(min(opacity * opacityScale, 1.0))),
                       style: StrokeStyle(lineWidth: stroke.brushSize * 0.65,
                                          lineCap: .round, lineJoin: .round))
        }
    }
```

### Step 4: Commit

```bash
git add ColoringApp/DrawingCanvasView.swift
git commit -m "feat: apply sizeVariation as opacity scale for user-created texture brushes"
```

---

## Task 5: Redesign KidBrushBuilderView as texture designer

**Why:** The current builder lets kids pick shapes (⭐❤️🌸) for a stamp-trail brush. The user wants it to feel like designing a paint brush — choose a texture (Crayon, Marker, Chalk, Glitter) and tune it.

**Files:**
- Modify: `ColoringApp/KidBrushBuilderView.swift`

### Step 1: Replace the entire file contents

The new file is a complete rewrite. Key changes:
- `selectedShape: PatternShape` → `selectedTexture: BrushBaseStyle = .crayon`
- `stampSpacing` kept (used for Glitter)
- Add `intensity: CGFloat = 0.5` (Soft ←→ Bold for texture brushes)
- Shape picker → texture picker (4 tiles using `KidBrushPreview`)
- Slider is contextual: intensity slider for .crayon/.marker/.chalk, spacing slider for .patternStamp
- Live canvas renders based on `selectedTexture`
- `save()` auto-selects the new brush

```swift
import SwiftUI

// MARK: - Kid Brush Builder Sheet

struct KidBrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedTexture: BrushBaseStyle = .crayon
    @State private var intensity: CGFloat = 0.5      // 0.0=soft, 1.0=bold (crayon/marker/chalk)
    @State private var stampSpacing: CGFloat = 1.2   // dense←→spread (glitter)
    @State private var previewPoints: [CGPoint] = []

    private let textures: [BrushBaseStyle] = [.crayon, .marker, .chalk, .patternStamp]
    private let brushSize: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──
            HStack {
                Text("🔮 Make a Brush!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // ── Live Preview Canvas ──
            GeometryReader { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 6)

                    if previewPoints.isEmpty {
                        Text("Draw here to try your brush!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.5))
                    } else {
                        Canvas { ctx, _ in
                            renderPreview(ctx: ctx)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in previewPoints.append(v.location) }
                        .onEnded   { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) { previewPoints = [] }
                            }
                        }
                )
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
            .onChange(of: selectedTexture) { _ in previewPoints = [] }
            .onChange(of: intensity)       { _ in previewPoints = [] }
            .onChange(of: stampSpacing)    { _ in previewPoints = [] }

            // ── Texture Picker ──
            VStack(spacing: 10) {
                Text("Pick a texture")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                HStack(spacing: 8) {
                    ForEach(textures, id: \.self) { texture in
                        KidTexturePickerTile(
                            style: texture,
                            isSelected: selectedTexture == texture,
                            previewColor: state.selectedColor
                        ) {
                            selectedTexture = texture
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── Contextual Slider ──
            VStack(spacing: 6) {
                if selectedTexture == .patternStamp {
                    Slider(value: $stampSpacing, in: 0.5...3.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("dense")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("spread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                } else {
                    Slider(value: $intensity, in: 0.0...1.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("soft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("bold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.top, 20)

            Spacer()

            // ── Save Button ──
            Button(action: save) {
                Text("✅  Use This Brush!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.4), radius: 8)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .kidSheetDetents()
        .kidDragIndicator()
    }

    // MARK: - Live Canvas Rendering

    private func renderPreview(ctx: GraphicsContext) {
        let color = state.selectedColor
        switch selectedTexture {
        case .crayon:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            let offsets: [(CGFloat, CGFloat, Double)] = [
                (-2.5,-1.5,0.50),(-1.0,-0.5,0.65),(0,0,0.72),(1.0,0.8,0.60),(2.2,1.5,0.45)
            ]
            for (dx, dy, op) in offsets {
                var path = Path()
                let pts = previewPoints.map { CGPoint(x: $0.x+dx, y: $0.y+dy) }
                guard let f = pts.first else { continue }
                path.move(to: f); pts.dropFirst().forEach { path.addLine(to: $0) }
                ctx.stroke(path, with: .color(color.opacity(min(op*scale,1.0))),
                           style: StrokeStyle(lineWidth: brushSize*0.85, lineCap:.round, lineJoin:.round))
            }

        case .marker:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            var path = Path()
            guard let f = previewPoints.first else { return }
            path.move(to: f); previewPoints.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(0.72*scale,1.0))),
                       style: StrokeStyle(lineWidth: brushSize*1.6, lineCap:.round, lineJoin:.round))

        case .chalk:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            let offsets: [(CGFloat, CGFloat, Double)] = [
                (-2.0,-1.5,0.30),(-0.8,-0.5,0.38),(0,0,0.42),(0.7,1.0,0.33),(1.8,-0.5,0.28)
            ]
            for (dx, dy, op) in offsets {
                var path = Path()
                let pts = previewPoints.map { CGPoint(x: $0.x+dx, y: $0.y+dy) }
                guard let f = pts.first else { continue }
                path.move(to: f); pts.dropFirst().forEach { path.addLine(to: $0) }
                ctx.stroke(path, with: .color(color.opacity(min(op*scale,1.0))),
                           style: StrokeStyle(lineWidth: brushSize*0.65, lineCap:.round, lineJoin:.round))
            }

        case .patternStamp:
            let spacing = stampSpacing * brushSize
            var last: CGPoint? = nil
            for pt in previewPoints {
                if let l = last, hypot(pt.x-l.x, pt.y-l.y) < spacing { continue }
                last = pt
                ctx.fill(PatternShape.star.path(center: pt, size: brushSize),
                         with: .color(color))
                let glintR = brushSize * 0.09
                ctx.fill(Ellipse().path(in: CGRect(x: pt.x-glintR, y: pt.y-glintR,
                                                   width: glintR*2, height: glintR*2)),
                         with: .color(.white.opacity(0.8)))
            }
        }
    }

    // MARK: - Save

    private func save() {
        let textureName: String
        switch selectedTexture {
        case .crayon:       textureName = "Crayon"
        case .marker:       textureName = "Marker"
        case .chalk:        textureName = "Chalk"
        case .patternStamp: textureName = "Glitter"
        }
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: "My \(textureName)",
            icon: selectedTexture.icon,
            baseStyle: selectedTexture,
            patternShape: selectedTexture == .patternStamp ? .star : nil,
            stampSpacing: selectedTexture == .patternStamp ? stampSpacing : 1.0,
            sizeVariation: selectedTexture != .patternStamp ? intensity : 0.0,
            isSystem: false
        )
        state.addBrush(descriptor)
        state.selectedBrush = descriptor
        state.isEraserMode  = false
        state.isStampMode   = false
        dismiss()
    }
}

// MARK: - Texture Picker Tile

struct KidTexturePickerTile: View {
    let style: BrushBaseStyle
    let isSelected: Bool
    let previewColor: Color
    let action: () -> Void

    private var sampleBrush: BrushDescriptor {
        BrushDescriptor(
            id: UUID(), name: "", icon: "",
            baseStyle: style,
            patternShape: style == .patternStamp ? .star : nil,
            stampSpacing: 1.2, sizeVariation: 0.5, isSystem: false
        )
    }

    private var styleName: String {
        switch style {
        case .crayon:       return "Crayon"
        case .marker:       return "Marker"
        case .chalk:        return "Chalk"
        case .patternStamp: return "Glitter"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                KidBrushPreview(brush: sampleBrush, color: previewColor)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(styleName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}
```

### Step 2: Commit

```bash
git add ColoringApp/KidBrushBuilderView.swift
git commit -m "feat: redesign kid brush builder as texture designer (Crayon/Marker/Chalk/Glitter)"
```

---

## Task 6: Build and push

### Step 1: Commit any remaining changes and push

```bash
git push origin main
```

### Step 2: SSH build on Mac

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

If errors appear: read the full log by dropping the `grep` filter and fix.

---

## Verification Checklist (simulator)

After build:
- [ ] Kid Mode brush strip shows wavy texture previews (no emoji icons)
- [ ] Crayon button looks waxy/layered, Marker looks solid, Chalk looks faded, Sparkle shows stars
- [ ] Tapping "Make a Brush!" opens builder with 4 texture tiles
- [ ] Each tile shows a canvas texture preview, not a symbol icon
- [ ] Soft ←→ Bold slider appears for Crayon/Marker/Chalk; Dense ←→ Spread for Glitter
- [ ] Drawing in live canvas preview uses selected texture style
- [ ] "Use This Brush!" immediately activates the new brush (drawing starts in that texture)
- [ ] New brush appears in the strip
- [ ] Rotating to portrait: canvas fills the screen, no collapsed layout
