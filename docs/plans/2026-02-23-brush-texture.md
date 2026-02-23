# Brush Texture & Pattern Customization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Replace the fixed `BrushType` enum with a unified `BrushDescriptor` system supporting curated pattern brushes, a toddler-friendly brush builder, and 3 persistent quick-access slots.

**Architecture:** `BrushDescriptor` (Codable struct) replaces `BrushType` everywhere. All brushes — system and user-created — are identical at runtime; curated brushes are pre-built descriptors with `isSystem: true`. The pool persists user-created brushes to UserDefaults; 3 slot UUIDs resolve against the pool on each launch.

**Tech Stack:** SwiftUI Canvas, `@ObservableObject`, `UserDefaults` + `Codable`, `fullScreenCover`, `LazyVGrid`.

**Design doc:** `docs/plans/2026-02-23-brush-texture-design.md`

---

## Task 7: Implement BrushDescriptor Data Model

**Files:**
- Modify: `ColoringApp/Models.swift`

This task replaces `BrushType` with `BrushDescriptor`, updates `Stroke`, and extends `DrawingState` with pool, slots, persistence, and eraser mode.

---

### Step 1: Add `BrushBaseStyle`, `PatternShape`, and icon extensions to `Models.swift`

Add after the existing `BrushType` enum (keep `BrushType` for now — it is deleted in Step 3):

```swift
// MARK: - Brush Descriptor System

enum BrushBaseStyle: String, Codable, CaseIterable {
    case crayon, marker, chalk, patternStamp

    var icon: String {
        switch self {
        case .crayon:       return "🖍️"
        case .marker:       return "🖊️"
        case .chalk:        return "🩫"
        case .patternStamp: return "🔵"
        }
    }
}

enum PatternShape: String, Codable, CaseIterable {
    case star, heart, dot, circle, square, diamond, flower, triangle

    var icon: String {
        switch self {
        case .star:     return "⭐"
        case .heart:    return "❤️"
        case .dot:      return "•"
        case .circle:   return "⭕"
        case .square:   return "■"
        case .diamond:  return "◆"
        case .flower:   return "🌸"
        case .triangle: return "▲"
        }
    }

    var displayName: String { rawValue.capitalized }
}

struct BrushDescriptor: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var baseStyle: BrushBaseStyle
    var patternShape: PatternShape?
    var stampSpacing: CGFloat        // multiplier of brushSize; range 0.5–3.0
    var sizeVariation: CGFloat       // 0.0 (uniform) → 1.0 (wild)
    var isSystem: Bool               // system brushes cannot be deleted from the pool

    // Fixed-UUID system brushes so slot UUIDs survive app restarts
    static let systemBrushes: [BrushDescriptor] = [
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                        name: "Crayon",   icon: "🖍️", baseStyle: .crayon,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                        name: "Marker",   icon: "🖊️", baseStyle: .marker,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                        name: "Sparkle",  icon: "✨", baseStyle: .patternStamp,
                        patternShape: .star, stampSpacing: 1.2, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                        name: "Chalk",    icon: "🩫", baseStyle: .chalk,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                        name: "Hearts",   icon: "❤️", baseStyle: .patternStamp,
                        patternShape: .heart, stampSpacing: 1.3, sizeVariation: 0.25, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                        name: "Dots",     icon: "•",  baseStyle: .patternStamp,
                        patternShape: .dot, stampSpacing: 0.9, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                        name: "Flowers",  icon: "🌸", baseStyle: .patternStamp,
                        patternShape: .flower, stampSpacing: 1.4, sizeVariation: 0.2, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
                        name: "Confetti", icon: "🎊", baseStyle: .patternStamp,
                        patternShape: .square, stampSpacing: 0.8, sizeVariation: 0.6, isSystem: true),
    ]

    // Used internally for eraser — never enters the pool
    static let eraser = BrushDescriptor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Eraser", icon: "⬜", baseStyle: .marker,
        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true
    )
}
```

---

### Step 2: Update `Stroke` to use `BrushDescriptor`

Replace the existing `Stroke` struct:

```swift
struct Stroke: Identifiable {
    let id = UUID()
    var points: [StrokePoint]
    let color: Color
    let brushSize: CGFloat
    let brush: BrushDescriptor          // was: brushType: BrushType
}
```

---

### Step 3: Remove the old `BrushType` enum

Delete the entire `BrushType` enum block from `Models.swift`. (Steps 4+ fix all callers.)

---

### Step 4: Rewrite `DrawingState`

Replace the entire `DrawingState` class:

```swift
class DrawingState: ObservableObject {
    // Active settings
    @Published var selectedColor: Color  = CrayolaColor.palette[0].color
    @Published var backgroundColor: Color = Color(r: 255, g: 250, b: 235)
    @Published var brushSize: CGFloat   = 24
    @Published var selectedBrush: BrushDescriptor = BrushDescriptor.systemBrushes[0]
    @Published var isEraserMode: Bool   = false
    @Published var selectedStamp: String = "🦋"
    @Published var isStampMode: Bool    = false

    // Brush pool & quick-access slots
    @Published var brushPool: [BrushDescriptor] = []
    @Published var slotAssignments: [UUID?] = [nil, nil, nil]

    // Drawing data
    @Published var strokes: [Stroke] = []
    @Published var stamps: [StampPlacement] = []
    @Published var currentStroke: Stroke? = nil

    // Undo stacks
    private var strokeHistory: [[Stroke]] = []
    private var stampHistory: [[StampPlacement]] = []

    init() {
        loadFromUserDefaults()
    }

    // MARK: - Pool Management

    func addBrush(_ brush: BrushDescriptor) {
        brushPool.append(brush)
        persist()
    }

    func deleteBrush(id: UUID) {
        brushPool.removeAll { $0.id == id && !$0.isSystem }
        slotAssignments = slotAssignments.map { $0 == id ? nil : $0 }
        persist()
    }

    func assignBrush(id: UUID, toSlot slot: Int) {
        guard slot >= 0 && slot < 3 else { return }
        slotAssignments[slot] = id
        persist()
    }

    // MARK: - Stroke Actions

    func beginStroke(at point: CGPoint) {
        let brush = isEraserMode ? BrushDescriptor.eraser : selectedBrush
        let color = isEraserMode ? backgroundColor : selectedColor
        currentStroke = Stroke(
            points: [StrokePoint(location: point)],
            color: color,
            brushSize: brushSize,
            brush: brush
        )
    }

    func continueStroke(at point: CGPoint) {
        currentStroke?.points.append(StrokePoint(location: point))
    }

    func endStroke() {
        guard let stroke = currentStroke else { return }
        strokeHistory.append(strokes)
        strokes.append(stroke)
        currentStroke = nil
    }

    func placeStamp(at point: CGPoint) {
        stampHistory.append(stamps)
        stamps.append(StampPlacement(
            emoji: selectedStamp,
            location: point,
            size: brushSize * 2.8
        ))
    }

    func undo() {
        if !strokeHistory.isEmpty { strokes = strokeHistory.removeLast() }
        if !stampHistory.isEmpty  { stamps  = stampHistory.removeLast()  }
    }

    func clear() {
        strokeHistory.append(strokes)
        stampHistory.append(stamps)
        strokes = []
        stamps = []
        currentStroke = nil
    }

    var canUndo: Bool { !strokeHistory.isEmpty || !stampHistory.isEmpty }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        let userBrushes: [BrushDescriptor]
        if let data = UserDefaults.standard.data(forKey: "brushPool"),
           let decoded = try? JSONDecoder().decode([BrushDescriptor].self, from: data) {
            userBrushes = decoded
        } else {
            userBrushes = []
        }
        brushPool = BrushDescriptor.systemBrushes + userBrushes

        if let slotStrings = UserDefaults.standard.stringArray(forKey: "slotAssignments"),
           slotStrings.count == 3 {
            slotAssignments = slotStrings.map { $0.isEmpty ? nil : UUID(uuidString: $0) ?? nil }
        }
    }

    private func persist() {
        let userBrushes = brushPool.filter { !$0.isSystem }
        if let data = try? JSONEncoder().encode(userBrushes) {
            UserDefaults.standard.set(data, forKey: "brushPool")
        }
        let slotStrings = slotAssignments.map { $0?.uuidString ?? "" }
        UserDefaults.standard.set(slotStrings, forKey: "slotAssignments")
    }
}
```

---

### Step 5: Verify the project builds

Open the project in Xcode. There will be compiler errors in `DrawingCanvasView.swift` and `ToolsView.swift` because they still reference `BrushType`. That is expected — Tasks 8 and 9 fix those. Confirm that `Models.swift` itself has zero errors.

---

### Step 6: Commit

```bash
git add ColoringApp/Models.swift
git commit -m "feat: replace BrushType with BrushDescriptor data model"
```

---

## Task 8: Update Renderer for BrushDescriptor

**Files:**
- Modify: `ColoringApp/DrawingCanvasView.swift`

Blocked by Task 7.

---

### Step 1: Update the `render` dispatch switch

Replace the existing `render(stroke:in:)` method:

```swift
private func render(stroke: Stroke, in ctx: GraphicsContext) {
    guard !stroke.points.isEmpty else { return }
    switch stroke.brush.baseStyle {
    case .crayon:       renderCrayon(stroke, in: ctx)
    case .marker:       renderMarker(stroke, in: ctx)
    case .chalk:        renderChalk(stroke, in: ctx)
    case .patternStamp: renderPatternStamp(stroke, in: ctx)
    }
}
```

---

### Step 2: Add `renderChalk`

Add after `renderCrayon`:

```swift
private func renderChalk(_ stroke: Stroke, in ctx: GraphicsContext) {
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
                   with: .color(stroke.color.opacity(opacity)),
                   style: StrokeStyle(lineWidth: stroke.brushSize * 0.65,
                                      lineCap: .round, lineJoin: .round))
    }
}
```

---

### Step 3: Add `renderPatternStamp` (replaces `renderSparkle`)

Delete `renderSparkle`. Add:

```swift
private func renderPatternStamp(_ stroke: Stroke, in ctx: GraphicsContext) {
    let shape = stroke.brush.patternShape ?? .dot
    let spacing = stroke.brush.stampSpacing * stroke.brushSize
    var lastPlaced: CGPoint? = nil

    for (index, pt) in stroke.points.enumerated() {
        if let last = lastPlaced {
            let dist = hypot(pt.location.x - last.x, pt.location.y - last.y)
            guard dist >= spacing else { continue }
        }
        lastPlaced = pt.location

        let jitter = deterministicJitter(index: index, strokeHash: stroke.id.hashValue)
        let size = stroke.brushSize * (1.0 + stroke.brush.sizeVariation * (jitter * 2.0 - 1.0))
        let stampPath = pathForShape(shape, center: pt.location, size: max(4, size))
        ctx.fill(stampPath, with: .color(stroke.color))

        // white center glint (kept from original Sparkle)
        if shape == .star {
            let glintR = size * 0.09
            let glintRect = CGRect(x: pt.location.x - glintR, y: pt.location.y - glintR,
                                   width: glintR * 2, height: glintR * 2)
            ctx.fill(Ellipse().path(in: glintRect), with: .color(.white.opacity(0.8)))
        }
    }
}

private func deterministicJitter(index: Int, strokeHash: Int) -> CGFloat {
    let h = (strokeHash ^ (index &* 2654435761)) & 0x7FFF_FFFF
    return CGFloat(h % 1000) / 1000.0
}
```

---

### Step 4: Add `pathForShape` dispatcher

```swift
private func pathForShape(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
    let r = size / 2
    switch shape {
    case .star:
        return makeStar(center: center, outerR: r, innerR: r * 0.42, points: 5)
    case .dot, .circle:
        return Ellipse().path(in: CGRect(x: center.x - r, y: center.y - r, width: size, height: size))
    case .square:
        return Rectangle().path(in: CGRect(x: center.x - r, y: center.y - r, width: size, height: size))
    case .diamond:
        return makeDiamond(center: center, size: size)
    case .heart:
        return makeHeart(center: center, size: size)
    case .flower:
        return makeFlower(center: center, size: size)
    case .triangle:
        return makeTriangle(center: center, size: size)
    }
}
```

---

### Step 5: Add shape path helpers

Add after `makeStar`:

```swift
private func makeDiamond(center: CGPoint, size: CGFloat) -> Path {
    let r = size / 2
    var p = Path()
    p.move(to:    CGPoint(x: center.x,     y: center.y - r))
    p.addLine(to: CGPoint(x: center.x + r, y: center.y))
    p.addLine(to: CGPoint(x: center.x,     y: center.y + r))
    p.addLine(to: CGPoint(x: center.x - r, y: center.y))
    p.closeSubpath()
    return p
}

private func makeTriangle(center: CGPoint, size: CGFloat) -> Path {
    let r = size / 2
    var p = Path()
    p.move(to:    CGPoint(x: center.x,     y: center.y - r))
    p.addLine(to: CGPoint(x: center.x + r, y: center.y + r))
    p.addLine(to: CGPoint(x: center.x - r, y: center.y + r))
    p.closeSubpath()
    return p
}

private func makeHeart(center: CGPoint, size: CGFloat) -> Path {
    // Two arcs for the lobes, curve to a point at the bottom
    let w = size, h = size
    let x = center.x - w / 2, y = center.y - h / 2
    var p = Path()
    p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85))
    p.addCurve(
        to:       CGPoint(x: x,          y: y + h * 0.35),
        control1: CGPoint(x: x + w * 0.1, y: y + h * 0.70),
        control2: CGPoint(x: x,           y: y + h * 0.50)
    )
    p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.25),
             radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.25),
             radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addCurve(
        to:       CGPoint(x: x + w * 0.5, y: y + h * 0.85),
        control1: CGPoint(x: x + w,        y: y + h * 0.50),
        control2: CGPoint(x: x + w * 0.9,  y: y + h * 0.70)
    )
    p.closeSubpath()
    return p
}

private func makeFlower(center: CGPoint, size: CGFloat) -> Path {
    // 6 petal circles orbiting a center circle
    var p = Path()
    let petalR = size * 0.28
    let orbit  = size * 0.24
    for i in 0..<6 {
        let angle = Double(i) / 6.0 * 2 * .pi
        let cx = center.x + CGFloat(cos(angle)) * orbit
        let cy = center.y + CGFloat(sin(angle)) * orbit
        p.addEllipse(in: CGRect(x: cx - petalR, y: cy - petalR, width: petalR * 2, height: petalR * 2))
    }
    let cr = petalR * 0.6
    p.addEllipse(in: CGRect(x: center.x - cr, y: center.y - cr, width: cr * 2, height: cr * 2))
    return p
}
```

---

### Step 6: Verify the project builds with zero errors

Both `Models.swift` and `DrawingCanvasView.swift` should now compile cleanly. `ToolsView.swift` still has errors — fixed in Task 9.

---

### Step 7: Commit

```bash
git add ColoringApp/DrawingCanvasView.swift
git commit -m "feat: update renderer for BrushDescriptor, add chalk and pattern stamp brushes"
```

---

## Task 9: Update Left Panel UI (ToolsView)

**Files:**
- Modify: `ColoringApp/ToolsView.swift`

Blocked by Task 7.

---

### Step 1: Replace `BrushToolsView` body

The panel now has four zones: system brushes, eraser, My Brushes slots, size picker.

Replace the entire file content:

```swift
import SwiftUI

// MARK: - Left Panel: Brush Tools + Size

struct BrushToolsView: View {
    @ObservedObject var state: DrawingState
    @State private var showingBuilder    = false
    @State private var showingPoolPicker = false
    @State private var targetSlot: Int   = 0

    private let sizes: [(String, CGFloat)] = [
        ("S", 10), ("M", 22), ("L", 40), ("XL", 60)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🎨")
                    .font(.system(size: 28))
                    .padding(.top, 4)

                Divider()

                // ── System Brushes ──
                VStack(spacing: 10) {
                    ForEach(BrushDescriptor.systemBrushes) { brush in
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
                }

                Divider()

                // ── My Brushes ──
                VStack(spacing: 8) {
                    Text("My Brushes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(0..<3, id: \.self) { slot in
                        SlotButton(
                            brush: brushForSlot(slot),
                            isSelected: isSlotSelected(slot),
                            onTap:      { selectSlot(slot) },
                            onLongPress: {
                                targetSlot        = slot
                                showingPoolPicker = true
                            }
                        )
                    }

                    Button(action: { showingBuilder = true }) {
                        Label("Build Brush", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // ── Size Picker ──
                VStack(spacing: 8) {
                    Text("Size")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(sizes, id: \.0) { label, size in
                        SizeButton(
                            label: label,
                            size: size,
                            isSelected: state.brushSize == size,
                            onTap: { state.brushSize = size }
                        )
                    }
                }

                Spacer()
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.12), radius: 6)
        )
        .fullScreenCover(isPresented: $showingBuilder) {
            BrushBuilderView(state: state)
        }
        .sheet(isPresented: $showingPoolPicker) {
            PoolPickerView(state: state, slot: targetSlot)
        }
    }

    // MARK: - Helpers

    private func brushForSlot(_ slot: Int) -> BrushDescriptor? {
        guard let id = state.slotAssignments[slot] else { return nil }
        return state.brushPool.first { $0.id == id }
    }

    private func isSlotSelected(_ slot: Int) -> Bool {
        guard !state.isStampMode && !state.isEraserMode,
              let brush = brushForSlot(slot) else { return false }
        return state.selectedBrush.id == brush.id
    }

    private func selectSlot(_ slot: Int) {
        guard let brush = brushForSlot(slot) else { return }
        state.selectedBrush = brush
        state.isStampMode   = false
        state.isEraserMode  = false
    }
}

// MARK: - BrushDescriptorButton

struct BrushDescriptorButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 26))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - SlotButton

struct SlotButton: View {
    let brush: BrushDescriptor?
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        let filled = brush != nil
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(brush?.icon ?? "＋")
                    .font(.system(size: filled ? 22 : 18))
                    .foregroundStyle(filled ? .primary : .tertiary)
                Text(brush?.name ?? "Empty")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(filled ? (isSelected ? .white : .primary) : .tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor
                          : (filled ? Color.gray.opacity(0.12) : Color.gray.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(filled ? Color.clear : Color.gray.opacity(0.25),
                                          style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

// MARK: - PoolPickerView

struct PoolPickerView: View {
    @ObservedObject var state: DrawingState
    let slot: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("System Brushes") {
                    ForEach(state.brushPool.filter { $0.isSystem }) { brush in
                        poolRow(brush)
                    }
                }
                if state.brushPool.contains(where: { !$0.isSystem }) {
                    Section("My Brushes") {
                        ForEach(state.brushPool.filter { !$0.isSystem }) { brush in
                            poolRow(brush)
                        }
                        .onDelete { indexSet in
                            let userBrushes = state.brushPool.filter { !$0.isSystem }
                            for i in indexSet {
                                state.deleteBrush(id: userBrushes[i].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Slot \(slot + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func poolRow(_ brush: BrushDescriptor) -> some View {
        Button(action: {
            state.assignBrush(id: brush.id, toSlot: slot)
            dismiss()
        }) {
            HStack {
                Text(brush.icon).font(.title2)
                Text(brush.name)
                Spacer()
                if state.slotAssignments[slot] == brush.id {
                    Image(systemName: "checkmark").foregroundStyle(.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - SizeButton (unchanged)

struct SizeButton: View {
    let label: String
    let size: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: min(size * 0.5, 26), height: min(size * 0.5, 26))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
```

Note: `BrushButton` is removed (replaced by `BrushDescriptorButton`). Check `ContentView.swift` for any reference to `BrushButton` and update if needed.

---

### Step 2: Fix any remaining `BrushType` references in other files

Search the project for `brushType` and `BrushType` — update any remaining callers to use `selectedBrush` / `isEraserMode` as appropriate.

---

### Step 3: Verify the project builds with zero errors

---

### Step 4: Commit

```bash
git add ColoringApp/ToolsView.swift
git commit -m "feat: update left panel with system brush list, My Brushes slots, and pool picker"
```

---

## Task 10: Build BrushBuilderView

**Files:**
- Create: `ColoringApp/BrushBuilderView.swift`

Blocked by Tasks 7 and 9.

---

### Step 1: Create `BrushBuilderView.swift`

```swift
import SwiftUI

// MARK: - Brush Builder (fullScreenCover)

struct BrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedStyle: BrushBaseStyle = .patternStamp
    @State private var selectedShape: PatternShape   = .heart
    @State private var stampSpacing: CGFloat         = 1.2
    @State private var sizeVariation: CGFloat        = 0.2
    @State private var brushName: String             = "My Hearts"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    styleSection
                    if selectedStyle == .patternStamp { shapeSection }
                    sliderSection
                    nameSection
                    saveButton
                }
                .padding(24)
            }
            .navigationTitle("Build Your Brush")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("STYLE")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(BrushBaseStyle.allCases, id: \.rawValue) { style in
                    StyleTile(
                        icon: style.icon,
                        label: style == .patternStamp ? "Pattern" : style.rawValue.capitalized,
                        isSelected: selectedStyle == style
                    ) {
                        selectedStyle = style
                        updateName()
                    }
                }
            }
        }
    }

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SHAPE")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(PatternShape.allCases, id: \.rawValue) { shape in
                    ShapeTile(shape: shape, isSelected: selectedShape == shape) {
                        selectedShape = shape
                        updateName()
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: selectedStyle)
    }

    private var sliderSection: some View {
        VStack(spacing: 20) {
            LabeledBuilderSlider(label: "SPACING",  value: $stampSpacing,  range: 0.5...3.0,
                                 leftNote: "dense", rightNote: "sparse")
            LabeledBuilderSlider(label: "SIZE MIX", value: $sizeVariation, range: 0.0...1.0,
                                 leftNote: "uniform", rightNote: "wild")
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NAME")
            TextField("Brush Name", text: $brushName)
                .font(.system(size: 22))
                .frame(height: 60)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.1))
                )
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("💾  Save Brush")
                .font(.system(size: 24, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.accentColor))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func updateName() {
        if selectedStyle == .patternStamp {
            brushName = "My \(selectedShape.displayName)s"
        } else {
            brushName = "My \(selectedStyle.rawValue.capitalized)"
        }
    }

    private func save() {
        let icon: String = selectedStyle == .patternStamp ? selectedShape.icon : selectedStyle.icon
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: brushName.isEmpty ? "My Brush" : brushName,
            icon: icon,
            baseStyle: selectedStyle,
            patternShape: selectedStyle == .patternStamp ? selectedShape : nil,
            stampSpacing: stampSpacing,
            sizeVariation: sizeVariation,
            isSystem: false
        )
        state.addBrush(descriptor)
        dismiss()
    }
}

// MARK: - StyleTile

struct StyleTile: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(icon).font(.system(size: 48))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - ShapeTile

struct ShapeTile: View {
    let shape: PatternShape
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(shape.icon).font(.system(size: 36))
                Text(shape.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - LabeledBuilderSlider

struct LabeledBuilderSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let leftNote: String
    let rightNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range)
                .controlSize(.large)
            HStack {
                Text(leftNote).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Text(rightNote).font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
```

---

### Step 2: Add `BrushBuilderView.swift` to the Xcode project target

In Xcode: right-click `ColoringApp` group → "Add Files to ColoringFun" → select `BrushBuilderView.swift` → ensure target membership is checked.

Alternatively, open `project.pbxproj` and add the file reference + build phase entry following the existing pattern for other Swift files. The easiest approach is using Xcode's UI.

---

### Step 3: Verify the project builds and runs on iPad Simulator

Run on an iPad (any size). Verify:
- [ ] All 8 system brushes appear in the left panel
- [ ] Eraser button appears and works
- [ ] 3 slot buttons appear, initially "Empty"
- [ ] Long-press on a slot opens the pool picker sheet
- [ ] Tapping a brush in the pool picker assigns it to the slot
- [ ] "+ Build Brush" opens the full-screen builder
- [ ] Style tiles are large and tappable
- [ ] Shape grid appears only when "Pattern" style is selected
- [ ] Sliders work; name auto-updates
- [ ] Saving creates a brush visible in the pool picker
- [ ] All 8 brush styles draw correctly on canvas
- [ ] Chalk has rough texture; pattern stamps appear along stroke path
- [ ] sizeVariation visibly affects stamp sizes

---

### Step 4: Commit

```bash
git add ColoringApp/BrushBuilderView.swift
git commit -m "feat: add BrushBuilderView full-screen brush creator for toddlers"
```

---

## Summary

| Task | Files | Blocked By |
|------|-------|------------|
| #7 Data Model | `Models.swift` | — |
| #8 Renderer | `DrawingCanvasView.swift` | #7 |
| #9 Left Panel UI | `ToolsView.swift` | #7 |
| #10 Builder Screen | `BrushBuilderView.swift` (new) | #7, #9 |
