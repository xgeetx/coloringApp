# Feedback Round 2 — Design

Date: 2026-02-25

## 1. Emoji Stamps — "Faces" Category

Add 5th stamp category to `allStampCategories` in `Models.swift`.

- **Name:** Faces | **Icon:** 😀 | **Tab color:** yellow pastel
- **16 stamps:** 😀😁😂🤣😄😆😊😋😍🥰🤗🥳🤩😎😜😢
- 15 happy/silly + 1 sad (😢) at the end

**Files:** `Models.swift` (category), `StampsView.swift` (tab color), `KidContentView.swift` (if kid stamp grid references categories)

## 2. Z-Axis Toggle — Stamps Layer Order

**Bug:** Canvas renders all stamps below all strokes. User expects newest-on-top.

**Solution:** Unified drawing element list + toggle.

### Data model changes (`Models.swift` / `DrawingState`)
- New enum `DrawingElement` with cases `.stroke(Stroke)` and `.stamp(StampPlacement)`
- New property `@Published var drawingElements: [DrawingElement] = []`
- New property `@Published var stampsAlwaysOnTop: Bool = false`
- `strokes` and `stamps` become computed properties filtering `drawingElements`
- Unified undo: single `elementHistory: [[DrawingElement]]` replaces `strokeHistory`/`stampHistory`

### Rendering changes (`DrawingCanvasView`)
- `stampsAlwaysOnTop == false` (default): render `drawingElements` in order — newest on top
- `stampsAlwaysOnTop == true`: render all strokes first, then all stamps on top
- Eraser stamp hit-test: unchanged (uses computed `stamps`)

### UI (`TopToolbarView`)
- Icon-only toggle button in top toolbar (layers icon)
- Visible always, indicates current mode

### Persistence (`DrawingPersistence.swift`)
- `DrawingSnapshot` gets unified `elements` array with `CodableDrawingElement`
- Backward compat: old snapshots with separate `strokes`/`stamps` arrays decode into creation order (stamps first, then strokes — matches old render behavior)

### Default
- Creation order (toggle off) — fixed behavior out of the box

## 3. Brush Slider Fix — Grain Spread Moves to Chalk

**Bug:** `KidBrushBuilderView` shows "tight grain → spread grain" slider for crayon. Should be on chalk. User chalk brushes never change because spread is hardcoded.

### UI changes (`KidBrushBuilderView`)
- Crayon: 1 slider only (soft/bold via `intensity`)
- Chalk: 2 sliders (soft/bold via `intensity` + tight/spread grain via `grainSpread`)
- Pattern stamp: unchanged (dense/spread via `stampSpacing`)

### Save logic (`KidBrushBuilderView.save()`)
- Crayon `stampSpacing` → `1.0` (fixed)
- Chalk `stampSpacing` → `grainSpread` (user-controlled)
- Pattern stamp `stampSpacing` → `stampSpacing` (unchanged)

### Rendering (`DrawingCanvasView.renderChalk()`)
- Before: `let spread = stroke.brushSize * 0.6`
- After: `let spread = stroke.brushSize * (stroke.brush.isSystem ? 0.6 : 0.6 * stroke.brush.stampSpacing)`

### Preview (`KidBrushBuilderView.renderPreview()`)
- Chalk preview: `let cSpread = brushSize * 0.6 * grainSpread`
