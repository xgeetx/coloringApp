# Kid Brush Previews Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Replace wavy-line brush previews with distinct static renders per medium (crayon/marker/chalk/sparkle), splatter dots for user-created brushes, and reorganise the brush strip to show user brushes in a bordered box above "Make" with a hard cap of 2.

**Architecture:** All changes are in `KidContentView.swift` and `KidBrushBuilderView.swift` — no new files, no pbxproj changes. `KidBrushPreview` routes on `brush.isSystem`: system brushes get a deterministic static render per `baseStyle`; user brushes get a seeded splatter dot cloud. `KidBrushStripView` is refactored to accept `systemBrushes` and `userBrushes` as separate arrays. Cap is enforced in `KidBrushBuilderView.save()`.

**Tech Stack:** SwiftUI Canvas API, iOS 15+, seeded deterministic PRNG (same `^ * 2654435761` hash used elsewhere in the codebase).

---

## Task 1: Rewrite `KidBrushPreview` with distinct medium renderers

**Files:**
- Modify: `ColoringApp/KidContentView.swift` — replace the entire `KidBrushPreview` struct (lines 392–465)

### Step 1: Replace the `KidBrushPreview` struct

Find and replace the entire struct from `// MARK: - Kid Brush Texture Preview` to the closing `}` before `#Preview`:

```swift
// MARK: - Kid Brush Texture Preview

struct KidBrushPreview: View {
    let brush: BrushDescriptor
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let seed = brush.id.hashValue & 0x7FFF_FFFF
            let w = size.width, h = size.height
            if brush.isSystem {
                switch brush.baseStyle {
                case .crayon:       drawCrayon(ctx: ctx, w: w, h: h, seed: seed)
                case .marker:       drawMarker(ctx: ctx, w: w, h: h)
                case .chalk:        drawChalk(ctx: ctx, w: w, h: h, seed: seed)
                case .patternStamp: drawSparkle(ctx: ctx, w: w, h: h, seed: seed)
                }
            } else {
                drawSplatter(ctx: ctx, w: w, h: h, seed: seed)
            }
        }
    }

    // Deterministic value in [0, 1) — same hash as DrawingCanvasView.deterministicJitter
    private func rng(_ seed: Int, _ i: Int) -> CGFloat {
        let h = (seed ^ (i &* 2654435761)) & 0x7FFF_FFFF
        return CGFloat(h % 10000) / 10000.0
    }

    // ── Crayon: diagonal band, 5 layered passes + paper-grain stipple ──
    private func drawCrayon(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let lw: CGFloat = min(w, h) * 0.38
        let start = CGPoint(x: 6, y: h - 6)
        let end   = CGPoint(x: w - 6, y: 6)
        let passes: [(CGFloat, CGFloat, Double)] = [
            (-4, -2, 0.38), (-2, -1, 0.55), (0, 0, 0.70), (2, 1, 0.52), (4, 2, 0.35)
        ]
        for (dx, dy, op) in passes {
            var path = Path()
            path.move(to: CGPoint(x: start.x + dx, y: start.y + dy))
            path.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy))
            ctx.stroke(path, with: .color(color.opacity(op)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        // Grain stipple — dots scattered along the diagonal band
        let ddx = end.x - start.x, ddy = end.y - start.y
        for i in 0..<80 {
            let t    = rng(seed, i * 4)
            let perp = rng(seed, i * 4 + 1) * 2 - 1
            let dotR = 0.4 + rng(seed, i * 4 + 2) * 1.4
            let op   = 0.05 + rng(seed, i * 4 + 3) * 0.20
            let x    = start.x + t * ddx + perp * lw * 0.5
            let y    = start.y + t * ddy + perp * lw * 0.3
            ctx.fill(Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                               width: dotR * 2, height: dotR * 2)),
                     with: .color(color.opacity(op)))
        }
    }

    // ── Marker: clean horizontal stroke + soft ink-bleed halo ──
    private func drawMarker(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let lw: CGFloat = min(w, h) * 0.46
        let y = h / 2
        // Halo first (wider, very faint — ink bleed)
        var haloPath = Path()
        haloPath.move(to: CGPoint(x: 6, y: y))
        haloPath.addLine(to: CGPoint(x: w - 6, y: y))
        ctx.stroke(haloPath, with: .color(color.opacity(0.10)),
                   style: StrokeStyle(lineWidth: lw * 1.5, lineCap: .round))
        // Solid stroke on top
        var path = Path()
        path.move(to: CGPoint(x: 6, y: y))
        path.addLine(to: CGPoint(x: w - 6, y: y))
        ctx.stroke(path, with: .color(color.opacity(0.88)),
                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // ── Chalk: 3 faint diagonal strokes + scattered dust dots ──
    private func drawChalk(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let lw: CGFloat = min(w, h) * 0.22
        let start = CGPoint(x: 6, y: h - 6)
        let end   = CGPoint(x: w - 6, y: 6)
        let passes: [(CGFloat, CGFloat, Double)] = [(-3, -2, 0.20), (0, 0, 0.26), (3, 2, 0.18)]
        for (dx, dy, op) in passes {
            var path = Path()
            path.move(to: CGPoint(x: start.x + dx, y: start.y + dy))
            path.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy))
            ctx.stroke(path, with: .color(color.opacity(op)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        // Chalk dust: micro-dots with wider spread than crayon grain
        let ddx = end.x - start.x, ddy = end.y - start.y
        for i in 0..<55 {
            let t    = rng(seed, i * 4)
            let perp = rng(seed, i * 4 + 1) * 2 - 1
            let dotR = 0.2 + rng(seed, i * 4 + 2) * 0.9
            let op   = 0.03 + rng(seed, i * 4 + 3) * 0.10
            let x    = start.x + t * ddx + perp * lw * 1.8
            let y    = start.y + t * ddy + perp * lw * 1.2
            ctx.fill(Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                               width: dotR * 2, height: dotR * 2)),
                     with: .color(color.opacity(op)))
        }
    }

    // ── Sparkle: scattered stars, no stroke ──
    private func drawSparkle(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        for i in 0..<6 {
            let x  = 8 + rng(seed, i * 3)     * (w - 16)
            let y  = 8 + rng(seed, i * 3 + 1) * (h - 16)
            let sz = 6 + rng(seed, i * 3 + 2) * 10
            ctx.fill(PatternShape.star.path(center: CGPoint(x: x, y: y), size: sz),
                     with: .color(color))
        }
    }

    // ── Splatter: seeded dot cloud for user-created brushes ──
    private func drawSplatter(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let cx = w / 2, cy = h / 2
        let maxR = min(w, h) * 0.44
        for i in 0..<30 {
            let angle  = rng(seed, i * 4)     * .pi * 2
            let radius = 2 + rng(seed, i * 4 + 1) * maxR
            let dotR   = 1 + rng(seed, i * 4 + 2) * 4.5
            let op     = 0.30 + rng(seed, i * 4 + 3) * 0.60
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            ctx.fill(
                Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                          width: dotR * 2, height: dotR * 2)),
                with: .color(color.opacity(op))
            )
        }
    }
}
```

### Step 2: Commit

```bash
git add ColoringApp/KidContentView.swift
git commit -m "feat: distinct static brush previews (crayon/marker/chalk/sparkle) + splatter for user brushes"
```

---

## Task 2: Refactor `KidBrushStripView` — separate arrays + bordered user-brush box

**Files:**
- Modify: `ColoringApp/KidContentView.swift`

### Step 1: Replace `textureBrushes` with two computed properties in `KidContentView`

Remove:
```swift
    // Texture-only brushes for the kid strip (no pattern-stamp icon brushes)
    private var textureBrushes: [BrushDescriptor] {
        let textureStyles: Set<BrushBaseStyle> = [.crayon, .marker, .chalk]
        let systemTexture = BrushDescriptor.systemBrushes.filter {
            textureStyles.contains($0.baseStyle) || $0.name == "Sparkle"
        }
        let userBrushes = state.brushPool.filter { !$0.isSystem }
        return systemTexture + userBrushes
    }
```

Add:
```swift
    private var systemTextureBrushes: [BrushDescriptor] {
        let textureStyles: Set<BrushBaseStyle> = [.crayon, .marker, .chalk]
        return BrushDescriptor.systemBrushes.filter {
            textureStyles.contains($0.baseStyle) || $0.name == "Sparkle"
        }
    }

    private var kidUserBrushes: [BrushDescriptor] {
        state.brushPool.filter { !$0.isSystem }
    }
```

### Step 2: Update `KidBrushStripView` call site in `KidContentView.body`

Replace:
```swift
                    KidBrushStripView(
                        state: state,
                        brushes: textureBrushes,
                        onBuildBrush: { showKidBuilder = true }
                    )
```

With:
```swift
                    KidBrushStripView(
                        state: state,
                        systemBrushes: systemTextureBrushes,
                        userBrushes: kidUserBrushes,
                        onBuildBrush: { showKidBuilder = true }
                    )
```

### Step 3: Rewrite `KidBrushStripView`

Replace the entire `KidBrushStripView` struct:

```swift
struct KidBrushStripView: View {
    @ObservedObject var state: DrawingState
    let systemBrushes: [BrushDescriptor]
    let userBrushes: [BrushDescriptor]    // max 2; capped at save time
    let onBuildBrush: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                // ── System brushes ──
                ForEach(systemBrushes) { brush in
                    KidBrushButton(
                        brush: brush,
                        isSelected: !state.isStampMode && !state.isEraserMode
                                    && state.selectedBrush.id == brush.id,
                        color: state.selectedColor
                    ) {
                        state.selectedBrush = brush
                        state.isStampMode   = false
                        state.isEraserMode  = false
                    }
                }

                // ── My Brushes: bordered box containing user brushes + Make ──
                VStack(spacing: 8) {
                    ForEach(userBrushes) { brush in
                        KidBrushButton(
                            brush: brush,
                            isSelected: !state.isStampMode && !state.isEraserMode
                                        && state.selectedBrush.id == brush.id,
                            color: state.selectedColor
                        ) {
                            state.selectedBrush = brush
                            state.isStampMode   = false
                            state.isEraserMode  = false
                        }
                    }

                    Button(action: onBuildBrush) {
                        VStack(spacing: 4) {
                            Text("🔮")
                                .font(.system(size: 26))
                            Text("Make")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.purple.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.purple.opacity(0.35),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        )
                )

                Spacer(minLength: 0)
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.14), radius: 8)
        )
    }
}
```

### Step 4: Commit

```bash
git add ColoringApp/KidContentView.swift
git commit -m "feat: bordered user-brush box in kid strip; separate system/user brush arrays"
```

---

## Task 3: Fix builder tile previews + enforce 2-brush cap at save

**Files:**
- Modify: `ColoringApp/KidBrushBuilderView.swift`

### Step 1: Fix `KidTexturePickerTile.sampleBrush` to use `isSystem: true`

The builder's texture picker tiles currently use `isSystem: false`, which would render splatter instead of the texture style. Change it so the tiles show the actual medium look.

In `KidTexturePickerTile`, replace:
```swift
    private var sampleBrush: BrushDescriptor {
        BrushDescriptor(
            id: UUID(), name: "", icon: "",
            baseStyle: style,
            patternShape: style == .patternStamp ? .star : nil,
            stampSpacing: 1.2, sizeVariation: 0.5, isSystem: false
        )
    }
```

With:
```swift
    private var sampleBrush: BrushDescriptor {
        BrushDescriptor(
            id: UUID(), name: "", icon: "",
            baseStyle: style,
            patternShape: style == .patternStamp ? .star : nil,
            stampSpacing: 1.2, sizeVariation: 0.5, isSystem: true
        )
    }
```

### Step 2: Enforce 2-brush cap in `KidBrushBuilderView.save()`

Replace the current `save()` function body:

```swift
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
        // Cap at 2: remove oldest user brush first if already at limit
        let userBrushes = state.brushPool.filter { !$0.isSystem }
        if userBrushes.count >= 2, let oldest = userBrushes.first {
            state.deleteBrush(id: oldest.id)
        }
        state.addBrush(descriptor)
        state.selectedBrush = descriptor
        state.isEraserMode  = false
        state.isStampMode   = false
        dismiss()
    }
```

### Step 3: Commit

```bash
git add ColoringApp/KidBrushBuilderView.swift
git commit -m "fix: builder tiles show texture style; enforce 2-brush cap (oldest replaced)"
```

---

## Task 4: Build and push

### Step 1: Push

```bash
git push origin main
```

### Step 2: SSH build

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

---

## Verification Checklist

After build:
- [ ] Crayon button shows a rough diagonal band with visible grain texture
- [ ] Marker button shows a bold clean horizontal stroke — noticeably different from Crayon
- [ ] Chalk button shows a faint, powdery diagonal — nearly invisible, clearly different from both
- [ ] Sparkle button shows scattered stars, no stroke
- [ ] All 4 look unmistakably different from each other
- [ ] User-created brushes show a splatter dot cloud
- [ ] Builder picker tiles (Crayon/Marker/Chalk/Glitter) show the correct texture style (not splatter)
- [ ] User brushes appear inside the dashed-border purple box above Make
- [ ] Make button is inside the box, not outside
- [ ] Saving a 3rd brush removes the oldest (first) user brush; only 2 ever visible
