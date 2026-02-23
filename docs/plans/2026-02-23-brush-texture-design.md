# Brush Texture & Pattern Customization — Design

**Date:** 2026-02-23
**App:** ColoringFun (iPad, iOS 15+, 3-year-old audience)

---

## Overview

Extend the brush system to support:
1. A curated palette of pre-built pattern/texture brushes
2. A toddler-friendly brush builder for creating custom brushes
3. A pool of saved custom brushes with 3 quick-access slots in the left panel

---

## Data Model

### Replace `BrushType` with `BrushDescriptor`

```swift
struct BrushDescriptor: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String           // emoji shown in the panel button
    var baseStyle: BrushBaseStyle
    var patternShape: PatternShape?  // only used when baseStyle == .patternStamp
    var stampSpacing: CGFloat        // multiplier of brushSize, range 0.5–3.0
    var sizeVariation: CGFloat       // 0.0 (uniform) → 1.0 (wild)
    var isSystem: Bool               // system brushes cannot be deleted
}

enum BrushBaseStyle: String, Codable, CaseIterable {
    case crayon, marker, chalk, patternStamp
}

enum PatternShape: String, Codable, CaseIterable {
    case star, heart, dot, circle, square, diamond, flower, triangle
}
```

### Changes to `Stroke`
- `brushType: BrushType` → `brush: BrushDescriptor`

### Changes to `DrawingState`
```swift
@Published var brushPool: [BrushDescriptor]    // system + user brushes
@Published var slotAssignments: [UUID?]         // 3 entries, nil = empty
@Published var selectedBrush: BrushDescriptor
```

Eraser remains a separate mode (not a `BrushDescriptor`).

---

## Curated System Brushes

Defined in `BrushDescriptor.systemBrushes` (static array, `isSystem: true`):

| Icon | Name     | baseStyle     | patternShape | spacing | sizeVariation |
|------|----------|---------------|--------------|---------|---------------|
| 🖍️   | Crayon   | .crayon       | —            | —       | —             |
| 🖊️   | Marker   | .marker       | —            | —       | —             |
| ✨   | Sparkle  | .patternStamp | .star        | 1.2     | 0.0           |
| 🩫   | Chalk    | .chalk        | —            | —       | —             |
| ❤️   | Hearts   | .patternStamp | .heart       | 1.3     | 0.25          |
| •    | Dots     | .patternStamp | .dot         | 0.9     | 0.0           |
| 🌸   | Flowers  | .patternStamp | .flower      | 1.4     | 0.2           |
| 🎊   | Confetti | .patternStamp | .square      | 0.8     | 0.6           |

---

## Rendering

Switch on `brush.baseStyle`:

```swift
switch stroke.brush.baseStyle {
case .crayon:       renderCrayon(stroke, in: ctx)       // existing 3-pass
case .marker:       renderMarker(stroke, in: ctx)       // existing semi-transparent
case .chalk:        renderChalk(stroke, in: ctx)        // new: 5-pass rough texture
case .patternStamp: renderPatternStamp(stroke, in: ctx) // generalized sparkle
}
```

**Chalk:** 5 passes with small random offsets and reduced opacity, simulating dry drag texture.

**PatternStamp:** Walks stroke points at `stampSpacing × brushSize` intervals, draws the `patternShape` path at each stop. Per-stamp size is `brushSize × (1 + sizeVariation × deterministicJitter(pointIndex))` — deterministic hash of point index ensures identical re-renders without storing random seeds.

**PatternShape path helpers:**
- `.star` → existing `makeStar()`
- `.dot`, `.circle` → `Ellipse` path
- `.square` → `Rectangle` path
- `.diamond` → `Rectangle` path rotated 45°
- `.heart`, `.flower`, `.triangle` → custom `Path` functions

---

## Left Panel UI

Three zones separated by dividers:

```
┌─────────────────┐
│  🎨              │  header (unchanged)
├─────────────────┤
│  System Brushes  │  BrushButton per system descriptor
│  🖍️ Crayon       │
│  🖊️ Marker       │
│  ...             │
├─────────────────┤
│  My Brushes      │  3 slot buttons
│  [Slot 1]        │  long-press → pool picker sheet
│  [Slot 2]        │
│  [Slot 3]        │
│  [+ Build Brush] │  opens BrushBuilderView fullScreenCover
├─────────────────┤
│  Size            │  S / M / L / XL (unchanged)
└─────────────────┘
```

**Slot buttons:** Show assigned brush icon + name, or "Empty". Long-press opens pool picker sheet.

**Pool picker sheet:** System brushes at top, user brushes below. Tap to assign to slot. Swipe-to-delete removes user brushes from pool (clears any slot pointing to that brush).

---

## Brush Builder (BrushBuilderView)

Opened as a `fullScreenCover` from "+ Build Brush". Large controls for toddler use:

```
┌──────────────────────────────────────────────────────┐
│  ✕  Build Your Brush                                  │
│                                                       │
│  STYLE                                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │    🖍️    │ │    🖊️    │ │    🩫    │ │   🔵    │ │
│  │  Crayon  │ │  Marker  │ │  Chalk   │ │ Pattern │ │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │
│                                                       │
│  SHAPE  (only shown when Style = Pattern)             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                │
│  │  ❤️  │ │  ⭐  │ │  •   │ │  🌸  │                │
│  └──────┘ └──────┘ └──────┘ └──────┘                │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                │
│  │  ◆   │ │  ■   │ │  ▲   │ │  ⭕  │                │
│  └──────┘ └──────┘ └──────┘ └──────┘                │
│                                                       │
│  SPACING     ●──────────  sparse                      │
│  SIZE MIX    ──────●────  medium                      │
│                                                       │
│  Name:  [ My Hearts              ]                    │
│                                                       │
│               [  💾 Save  ]                           │
└──────────────────────────────────────────────────────┘
```

- Style tiles: ~120×120pt, emoji at 48pt
- Shape grid: 4×2 `LazyVGrid`, ~90×90pt tiles
- Sliders: `.controlSize(.large)`
- Name field and Save button: 60pt tall
- Name defaults to shape name (e.g. "My Hearts")
- ✕ dismisses without saving; Save appends to `brushPool` and dismisses

---

## Persistence

**UserDefaults keys:**
- `"brushPool"` → `[BrushDescriptor]` (user-created only; system brushes always re-injected from code)
- `"slotAssignments"` → `[String?]` (3 UUID strings, nil = empty)

**On launch:** Load user brushes, prepend system brushes → full `brushPool`. Resolve slot UUIDs against pool. Default `selectedBrush` to Crayon.

**On change:** Private `persist()` filters out system brushes, encodes and writes to UserDefaults whenever `brushPool` or `slotAssignments` changes.

---

## Implementation Tasks

| Task | Description | Blocked By |
|------|-------------|------------|
| #7   | Implement BrushDescriptor data model | — |
| #8   | Update renderer for BrushDescriptor | #7 |
| #9   | Update left panel UI for slots and system brushes | #7 |
| #10  | Build BrushBuilderView fullScreenCover | #7, #9 |
