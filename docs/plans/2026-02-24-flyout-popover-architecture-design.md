# Flyout Popover Architecture — Design

**Date:** 2026-02-24
**Depends on:** `2026-02-24-wife-feedback-fixes` merged first
**Motivation:** Current fixed sidebar panels (100pt left, 120pt right) are cramped, cut off in portrait mode, and expose too many options at once. Replace with narrow icon strips that trigger clearly-dismissible flyout panels sliding in from the sides.

---

## Core Concept

The sides of the screen remain the trigger zone — the location and visual language stays familiar. Panels collapse to a narrow icon strip. Tapping an icon slides a flyout panel over the canvas. The flyout is clearly floating (not full-width, has a drop shadow), and is dismissed either by a large X button on the flyout itself or by tapping the canvas a safe distance from the strip.

---

## Layout

### Panels closed (default state)

```
[Top Toolbar: 🏠 | Title | BG | Undo | Clear | Eraser]
[Left Strip ~44pt] | [Canvas — wider] | [Right Strip ~44pt]
[ColorPaletteView — full width]
```

Left and right strips are narrow columns of large icon buttons. Canvas gains ~112pt of width vs current layout.

### Left flyout open

```
[Top Toolbar]
[Left Strip | Flyout ~260pt (overlaps canvas) | Canvas] | [Right Strip]
[ColorPaletteView]
```

Flyout slides in from the left, floating over the canvas with a shadow. Canvas content is still visible and partially interactive behind it.

### Right flyout open

Mirror of above — flyout slides in from the right.

---

## Left Icon Strip

Icons stacked vertically, centered in ~44pt strip:

| Icon | SF Symbol | Opens |
|---|---|---|
| Brush | `paintbrush.fill` | Brushes flyout |
| Size | `lineweight` | Size flyout |
| Opacity | `circle.lefthalf.filled` | Opacity flyout |

Active icon is highlighted with accent color.

---

## Right Icon Strip

| Icon | SF Symbol | Opens |
|---|---|---|
| Stamps | `seal.fill` | Stamps flyout |

---

## Flyout Panels

### Shared behavior
- Fixed width: ~260pt
- Height: full panel height (matches canvas height)
- Slides in with spring animation from the respective edge
- Drop shadow on the canvas-facing edge to clearly separate it from canvas
- **Large X button** in the top corner of the flyout (opposite the strip side) — tappable area at least 44×44pt
- **Canvas tap-to-dismiss:** a tap gesture on the canvas dismisses any open flyout, with a dead zone of ~20pt along the strip edge to prevent accidental dismissal when reaching for the icon strip

### Brushes flyout (left)
- 3 quick-access slot buttons (existing slot system)
- "All Brushes" → opens `PoolPickerView` sheet

### Size flyout (left)
- Single large vertical slider for brush size
- Live preview dot showing current size

### Opacity flyout (left)
- Single large vertical slider for opacity (0.1–1.0)
- Live preview swatch showing current color at current opacity

### Stamps flyout (right)
- Category tab row (existing horizontal icon scroll)
- Stamp grid (existing `LazyVGrid`)
- On stamp selection: flyout auto-dismisses, stamp mode activates

---

## Dismiss Behavior

| Action | Result |
|---|---|
| Tap X button on flyout | Flyout slides back out |
| Tap canvas >20pt from strip edge | Flyout slides back out |
| Tap same icon strip button again | Flyout slides back out (toggle) |
| Tap different icon strip button | Previous flyout slides out, new one slides in |
| Begin drawing stroke | Flyout slides back out |

---

## Portrait Mode

With narrow strips instead of fixed panels, the canvas gains significant horizontal space. In portrait mode the strips remain on the sides — no layout changes needed for orientation. The flyouts still slide in from their respective edges at the same 260pt width.

---

## State Management

A single `@State var activeFlyout: FlyoutPanel?` enum in `ContentView` (or a wrapper view) controls which flyout is open. `FlyoutPanel` is an enum: `.brushes`, `.size`, `.opacity`, `.stamps`. `nil` = all closed.

---

## Animation

- Open: `.spring(response: 0.35, dampingFraction: 0.75)` slide from edge
- Close: `.easeIn(duration: 0.2)` slide back to edge
- X button: visible immediately when flyout is open, no delay

---

## Files Changed

| File | Changes |
|---|---|
| `ContentView.swift` | Replace fixed-width panels with strips + flyout overlay logic; add canvas tap-to-dismiss gesture |
| `LeftStripView.swift` | **New.** Narrow icon column, highlights active flyout |
| `RightStripView.swift` | **New.** Narrow icon column for stamps |
| `FlyoutContainerView.swift` | **New.** Shared flyout wrapper: slide animation, X button, shadow |
| `ToolsView.swift` | Refactored into three focused views: `BrushesFlyoutView`, `SizeFlyoutView`, `OpacityFlyoutView` |
| `StampsView.swift` | Becomes `StampsFlyoutView` — same content, no fixed frame |
| `ColorPaletteView.swift` | Unchanged — stays as full-width bottom bar |
| `project.pbxproj` | Register all new files (4 insertions each) |

---

## Sequencing Note

This plan runs **after** `2026-02-24-wife-feedback-fixes` is merged. The opacity slider and system `ColorPicker` from that plan slot directly into the flyout content views here with no duplication.
