# Kid Mode + Parent Mode Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated "Kids Mode" hub tile with an always-visible, large-target UI designed for a 3-year-old, alongside targeted fixes to the parent-mode coloring app (BrushBuilder as sheet, full brush pool visible, strip contrast fix).

**Architecture:** `KidContentView` is a new root view registered in `AppRegistry` using the existing `DrawingState` / `DrawingCanvasView` / `StampsFlyoutView` — no engine changes. `KidBrushBuilderView` is a new sheet with a live interactive preview canvas. Parent-mode fixes are in-place edits to existing files.

**Tech Stack:** SwiftUI, existing DrawingState (ObservableObject), Canvas API for live brush preview, UserDefaults for persistence (already handled by DrawingState).

---

## Task 1: Create `KidContentView.swift`

**Files:**
- Create: `ColoringApp/KidContentView.swift`

The main kid-mode root view. Left strip = texture brushes only + Build button. Right panel = 2×4 stamp grid + "More" button. Bottom = full-width color palette (reuse `ColorPaletteView`). Top = minimal 4-button toolbar.

**Step 1: Create the file**

```swift
import SwiftUI

// MARK: - Kid Mode Root View

struct KidContentView: View {
    @StateObject private var state = DrawingState()
    @State private var showMoreStamps  = false
    @State private var showKidBuilder  = false

    // Texture-only brushes for the kid strip (no pattern-stamp icon brushes)
    private var textureBrushes: [BrushDescriptor] {
        let textureStyles: Set<BrushBaseStyle> = [.crayon, .marker, .chalk]
        let systemTexture = BrushDescriptor.systemBrushes.filter {
            textureStyles.contains($0.baseStyle) || $0.name == "Sparkle"
        }
        let userBrushes = state.brushPool.filter { !$0.isSystem }
        return systemTexture + userBrushes
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(r: 255, g: 200, b: 220),
                    Color(r: 255, g: 230, b: 180),
                    Color(r: 200, g: 230, b: 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {

                // ── Top Toolbar ──
                KidTopToolbarView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

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
                        DrawingCanvasView(state: state)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)

                        // Stamp mode banner
                        if state.isStampMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    Label("Tap to stamp  \(state.selectedStamp)", systemImage: "hand.tap.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color.purple.opacity(0.85)))
                                    Spacer()
                                }
                                .padding(.top, 12)
                                Spacer()
                            }
                        }
                    }

                    // Right: quick stamp grid
                    KidStampGridView(state: state, onMoreTapped: { showMoreStamps = true })
                        .frame(width: 100)
                }
                .padding(.horizontal, 12)

                // ── Bottom: colour palette ──
                ColorPaletteView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showKidBuilder) {
            KidBrushBuilderView(state: state)
        }
        .sheet(isPresented: $showMoreStamps) {
            // Reuse existing stamps flyout; dismiss = close sheet
            StampsFlyoutView(state: state, onDismiss: { showMoreStamps = false })
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Kid Top Toolbar

struct KidTopToolbarView: View {
    @ObservedObject var state: DrawingState
    @State private var showClearConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            KidToolbarButton(icon: "arrow.uturn.backward", label: "Undo",  color: .blue,
                             disabled: !state.canUndo) { state.undo() }

            KidToolbarButton(
                icon: "eraser.fill", label: "Erase",
                color: .orange, disabled: false,
                isActive: state.isEraserMode
            ) {
                state.isEraserMode.toggle()
                if state.isEraserMode { state.isStampMode = false }
            }

            Spacer()

            KidToolbarButton(icon: "trash", label: "Clear", color: .red, disabled: false) {
                showClearConfirm = true
            }
            .confirmationDialog("Clear the whole drawing?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear It! 🗑️", role: .destructive) { state.clear() }
                Button("Keep It! 🎨", role: .cancel) {}
            }

            KidToolbarButton(icon: "house.fill", label: "Home", color: .indigo, disabled: false) {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
    }
}

struct KidToolbarButton: View {
    let icon: String
    let label: String
    let color: Color
    let disabled: Bool
    var isActive: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            action()
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(disabled ? .gray : (isActive ? .white : color))
            .frame(width: 64, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(disabled ? Color.gray.opacity(0.08)
                          : (isActive ? color : color.opacity(0.15)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isActive ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Kid Brush Strip (left panel)

struct KidBrushStripView: View {
    @ObservedObject var state: DrawingState
    let brushes: [BrushDescriptor]
    let onBuildBrush: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(brushes) { brush in
                    KidBrushButton(
                        brush: brush,
                        isSelected: !state.isStampMode && !state.isEraserMode
                                    && state.selectedBrush.id == brush.id
                    ) {
                        state.selectedBrush = brush
                        state.isStampMode   = false
                        state.isEraserMode  = false
                    }
                }

                Divider().padding(.horizontal, 6)

                // Build a Brush button
                Button(action: onBuildBrush) {
                    VStack(spacing: 4) {
                        Text("🔮")
                            .font(.system(size: 30))
                        Text("Make")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.purple.opacity(0.3),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            )
                    )
                }
                .buttonStyle(.plain)

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

struct KidBrushButton: View {
    let brush: BrushDescriptor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(brush.icon)
                    .font(.system(size: 32))
                Text(brush.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
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

// MARK: - Kid Stamp Grid (right panel)

/// Shows the first 8 stamps from the first category, plus a "More" button.
struct KidStampGridView: View {
    @ObservedObject var state: DrawingState
    let onMoreTapped: () -> Void

    // Fixed 8 quick-access stamps — first 8 animals
    private let quickStamps: [String] = Array(
        (allStampCategories.first?.stamps ?? []).prefix(8)
    )

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(quickStamps, id: \.self) { emoji in
                    Button(action: {
                        state.selectedStamp = emoji
                        state.isStampMode   = true
                        state.isEraserMode  = false
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    state.selectedStamp == emoji && state.isStampMode
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.white.opacity(0.7)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            state.selectedStamp == emoji && state.isStampMode
                                            ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            Text(emoji)
                                .font(.system(size: 28))
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // "More" button
            Button(action: onMoreTapped) {
                Label("More", systemImage: "chevron.down.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.14), radius: 8)
        )
    }
}

#Preview {
    KidContentView()
}
```

**Step 2: Build on Mac to verify compilation**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add ColoringApp/KidContentView.swift
git commit -m "feat: add KidContentView with texture brush strip and quick stamp grid"
```

---

## Task 2: Create `KidBrushBuilderView.swift`

**Files:**
- Create: `ColoringApp/KidBrushBuilderView.swift`

Interactive sheet: live preview canvas (user draws in it), shape picker (5 big buttons), spread slider, "Use This Brush!" save button. No name input — auto-named from shape.

**Step 1: Create the file**

```swift
import SwiftUI

// MARK: - Kid Brush Builder Sheet

struct KidBrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedShape: PatternShape = .star
    @State private var stampSpacing: CGFloat = 1.2
    @State private var previewPoints: [CGPoint] = []

    // Quick-access shapes for the kid picker
    private let shapes: [PatternShape] = [.star, .heart, .flower, .diamond, .dot]

    private let brushSize: CGFloat = 28

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
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 6)

                    if previewPoints.isEmpty {
                        Text("Draw here to try your brush!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.5))
                    } else {
                        Canvas { ctx, size in
                            let spacing = stampSpacing * brushSize
                            var lastPlaced: CGPoint? = nil
                            for pt in previewPoints {
                                if let last = lastPlaced {
                                    let dist = hypot(pt.x - last.x, pt.y - last.y)
                                    guard dist >= spacing else { continue }
                                }
                                lastPlaced = pt
                                let path = kidShapePath(selectedShape, center: pt, size: brushSize)
                                ctx.fill(path, with: .color(state.selectedColor))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in previewPoints.append(v.location) }
                        .onEnded   { _ in
                            // Clear after 1.5 s so user can try again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) { previewPoints = [] }
                            }
                        }
                )
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
            .onChange(of: selectedShape)  { _ in previewPoints = [] }
            .onChange(of: stampSpacing)   { _ in previewPoints = [] }

            // ── Shape Picker ──
            VStack(spacing: 10) {
                Text("Pick a shape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                HStack(spacing: 12) {
                    ForEach(shapes, id: \.self) { shape in
                        Button(action: { selectedShape = shape }) {
                            Text(shape.icon)
                                .font(.system(size: 38))
                                .frame(width: 64, height: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedShape == shape
                                              ? Color.accentColor.opacity(0.22)
                                              : Color.gray.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(
                                                    selectedShape == shape ? Color.accentColor : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(selectedShape == shape ? 1.10 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedShape)
                    }
                }
            }

            // ── Spread Slider ──
            VStack(spacing: 6) {
                Slider(value: $stampSpacing, in: 0.5...3.0)
                    .tint(.purple)
                    .padding(.horizontal, 24)
                HStack {
                    Text("close together")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("spread out")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func save() {
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: "My \(selectedShape.displayName)s",
            icon: selectedShape.icon,
            baseStyle: .patternStamp,
            patternShape: selectedShape,
            stampSpacing: stampSpacing,
            sizeVariation: 0.0,
            isSystem: false
        )
        state.addBrush(descriptor)
        dismiss()
    }

    /// Minimal shape path renderer for the live preview (mirrors DrawingCanvasView logic).
    private func kidShapePath(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch shape {
        case .star:
            return makeStar(center: center, outerR: r, innerR: r * 0.42, points: 5)
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

    private func makeStar(center: CGPoint, outerR: CGFloat, innerR: CGFloat, points: Int) -> Path {
        var path = Path()
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let rr: CGFloat = i % 2 == 0 ? outerR : innerR
            let x = center.x + rr * CGFloat(cos(angle))
            let y = center.y + rr * CGFloat(sin(angle))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}
```

**Step 2: Build**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add ColoringApp/KidBrushBuilderView.swift
git commit -m "feat: add KidBrushBuilderView with interactive live preview canvas"
```

---

## Task 3: Register new files in `project.pbxproj`

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj`

Add 4 entries each for `KidContentView.swift` and `KidBrushBuilderView.swift`.

**UUIDs to use:**

| File | fileRef UUID | buildFile UUID |
|---|---|---|
| KidContentView.swift | `A2B2C3D4E5F6A7B8C9D0E1F2` | `B3C3D4E5F6A7B8C9D0E1F2A3` |
| KidBrushBuilderView.swift | `C4D4E5F6A7B8C9D0E1F2A3B4` | `D5E5F6A7B8C9D0E1F2A3B4C5` |

**Step 1: PBXBuildFile section** — add before `/* End PBXBuildFile section */`:
```
		B3C3D4E5F6A7B8C9D0E1F2A3 /* KidContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2B2C3D4E5F6A7B8C9D0E1F2 /* KidContentView.swift */; };
		D5E5F6A7B8C9D0E1F2A3B4C5 /* KidBrushBuilderView.swift in Sources */ = {isa = PBXBuildFile; fileRef = C4D4E5F6A7B8C9D0E1F2A3B4 /* KidBrushBuilderView.swift */; };
```

**Step 2: PBXFileReference section** — add before `/* End PBXFileReference section */`:
```
		A2B2C3D4E5F6A7B8C9D0E1F2 /* KidContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KidContentView.swift; sourceTree = "<group>"; };
		C4D4E5F6A7B8C9D0E1F2A3B4 /* KidBrushBuilderView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KidBrushBuilderView.swift; sourceTree = "<group>"; };
```

**Step 3: PBXGroup children** — add inside the `ColoringApp` group (after `DrawingPersistence.swift` line):
```
				A2B2C3D4E5F6A7B8C9D0E1F2 /* KidContentView.swift */,
				C4D4E5F6A7B8C9D0E1F2A3B4 /* KidBrushBuilderView.swift */,
```

**Step 4: PBXSourcesBuildPhase** — add inside Sources files list:
```
				B3C3D4E5F6A7B8C9D0E1F2A3 /* KidContentView.swift in Sources */,
				D5E5F6A7B8C9D0E1F2A3B4C5 /* KidBrushBuilderView.swift in Sources */,
```

**Step 5: Build**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Step 6: Commit**

```bash
git add ColoringFun.xcodeproj/project.pbxproj
git commit -m "chore: register KidContentView and KidBrushBuilderView in pbxproj"
```

---

## Task 4: Add Kids Mode tile to `AppRegistry.swift`

**Files:**
- Modify: `ColoringApp/AppRegistry.swift`

Replace the `app2` placeholder ("Music Maker") with a live Kids Mode tile.

**Step 1: Edit `AppRegistry.swift`**

Replace:
```swift
        .placeholder(id: "app2", icon: "🎵", displayName: "Music Maker"),
```
With:
```swift
        MiniAppDescriptor(
            id: "kidsmode",
            displayName: "Kids Mode",
            subtitle: "Paint & Play!",
            icon: "🌈",
            tileColor: Color(r: 180, g: 230, b: 255),
            isAvailable: true,
            makeRootView: { AnyView(KidContentView()) }
        ),
```

**Step 2: Build**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Step 3: Commit**

```bash
git add ColoringApp/AppRegistry.swift
git commit -m "feat: add Kids Mode tile to hub using KidContentView"
```

---

## Task 5: Fix `BrushBuilderView` — sheet instead of fullScreenCover

**Files:**
- Modify: `ColoringApp/ToolsView.swift` (line ~129)

**Step 1: In `BrushesFlyoutView.body`, change `.fullScreenCover` to `.sheet`**

Find:
```swift
        .fullScreenCover(isPresented: $showingBuilder) {
            BrushBuilderView(state: state)
        }
```
Replace with:
```swift
        .sheet(isPresented: $showingBuilder) {
            BrushBuilderView(state: state)
        }
```

**Step 2: Build and commit**

```bash
git add ColoringApp/ToolsView.swift
git commit -m "fix: BrushBuilderView as sheet instead of fullScreenCover"
```

---

## Task 6: Fix `BrushesFlyoutView` — show full user brush pool

**Files:**
- Modify: `ColoringApp/ToolsView.swift`

Currently user brushes only appear in `PoolPickerView` (hidden behind a long-press). Show them directly in the flyout below system brushes.

**Step 1: In `BrushesFlyoutView.body`, replace the "My Brushes" slots section**

Find and replace the entire `// ── My Brushes ──` VStack:

```swift
                Divider()

                // ── My Brushes ──
                if state.brushPool.contains(where: { !$0.isSystem }) {
                    VStack(spacing: 8) {
                        Text("My Brushes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(state.brushPool.filter { !$0.isSystem }) { brush in
                            BrushDescriptorButton(
                                icon: brush.icon,
                                label: brush.name,
                                isSelected: !state.isStampMode && !state.isEraserMode
                                            && state.selectedBrush.id == brush.id,
                                onTap: {
                                    state.selectedBrush = brush
                                    state.isStampMode   = false
                                    state.isEraserMode  = false
                                }
                            )
                        }
                    }

                    Divider()
                }
```

Also remove the now-unused slot infrastructure: `@State private var targetSlot`, `@State private var showingPoolPicker`, the 3 slot `ForEach` loop, and the `.sheet(isPresented: $showingPoolPicker)` modifier. Remove the `brushForSlot`, `isSlotSelected`, `selectSlot` helper methods, and the `PoolPickerView` call.

> **Note:** Keep `PoolPickerView` struct in the file for now — it may be referenced elsewhere. Only remove it from `BrushesFlyoutView`.

**Step 2: Build**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

**Step 3: Commit**

```bash
git add ColoringApp/ToolsView.swift
git commit -m "fix: show full user brush pool directly in BrushesFlyoutView"
```

---

## Task 7: Fix strip visual contrast (portrait mode)

**Files:**
- Modify: `ColoringApp/LeftStripView.swift`
- Modify: `ColoringApp/RightStripView.swift`

The `.white.opacity(0.75)` background blends into the app gradient in portrait. Replace with `.ultraThinMaterial` + a stronger colored accent on active icons.

**Step 1: In `LeftStripView.body`, change the background**

Find:
```swift
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.75))
                .shadow(color: .black.opacity(0.10), radius: 6)
        )
```
Replace with:
```swift
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 2, y: 2)
        )
```

**Step 2: In `RightStripView.body`, apply the same background change** (identical pattern).

**Step 3: In `StripIconButton`, increase icon font size from 20 to 22pt**

Find:
```swift
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
```
Replace with:
```swift
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
```

**Step 4: Build and commit**

```bash
git add ColoringApp/LeftStripView.swift ColoringApp/RightStripView.swift
git commit -m "fix: improve strip visual contrast and icon size for portrait mode"
```

---

## Task 8: Final build, push, and install check

**Step 1: Full build on Mac**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|warning: |BUILD)'"
```
Expected: `** BUILD SUCCEEDED **` with zero errors.

**Step 2: Push**

```bash
git push
```

**Step 3: Verify hub shows both tiles**

Manual check: Hub should show 🎨 Coloring Fun + 🌈 Kids Mode as live tiles, 🧩 Puzzle Play + 📖 Story Time as "Coming Soon".

**Step 4: Verify Kids Mode**

- Texture brush strip visible on left
- 8 stamps on right with "More" button
- Build-a-Brush opens as a sheet with live preview canvas
- Color palette at bottom
- Undo/Erase/Clear/Home in top bar

**Step 5: Verify parent mode fixes**

- BrushBuilder opens as sheet (not fullscreen)
- User-created brushes appear directly in BrushesFlyoutView after saving
- Strips more visually distinct in portrait orientation
