# Wife Feedback Fixes — Design

**Date:** 2026-02-24
**Source:** User testing session with wife on physical iPad
**Scope:** 11 changes — quick fixes, UI layout adjustments, one new gesture, and two new features

---

## 1. Stamp Auto-Select on Category Change

**Problem:** Switching stamp categories (e.g. Animals → Insects) leaves the previously selected stamp active, so tapping the canvas places an animal stamp even though insects are shown.

**Fix:** In `StampsView.swift`, add `.onChange(of: selectedCategoryIndex)` that sets `state.selectedStamp` to `allStampCategories[selectedCategoryIndex].stamps[0]` and ensures `state.isStampMode = true`.

---

## 2. Eraser: Hard Erase Only

**Problem:** Eraser currently inherits opacity behavior from the marker base style, producing a soft partial erase.

**Fix:** In `DrawingCanvasView.swift`, when rendering strokes with the eraser brush (detected via `stroke.brush.id == BrushDescriptor.eraser.id`), always draw at `opacity: 1.0`. Eraser ignores `brushOpacity` entirely.

---

## 3. Eraser Icon

**Problem:** Current icon `⬜` looks generic and confusing.

**Fix:** Since eraser moves to the top toolbar (item 6), use SF Symbol `eraser.fill` rendered as `Image(systemName: "eraser.fill")` in `TopToolbarView`. No change needed in `Models.swift`.

---

## 4. Hearts Brush: Uniform Size

**Problem:** Hearts brush has `sizeVariation: 0.25`, causing hearts to render at different sizes as the user draws. Feels glitchy.

**Fix:** In `Models.swift`, change the Hearts system brush `sizeVariation` from `0.25` → `0.0`.

---

## 5. Crayon Brush: More Distinct Feel

**Problem:** Crayon doesn't look or feel noticeably different from other brushes.

**Fix:** In `DrawingCanvasView.swift`, enhance the `.crayon` rendering path:
- Increase from 3 passes to 5 passes
- Add slight random hue/brightness variation per pass (±5%)
- Increase per-pass opacity from current value to make wax texture more visible
- Add a very slight edge roughness effect by jittering each pass position by ±2pt

---

## 6. Eraser → Top Toolbar

**Problem:** Eraser is buried in the left tools panel, far from reach for a 3-year-old.

**Fix:**
- Add an eraser toggle button to `TopToolbarView` on the left side (after the 🏠 Home button)
- Button shows `Image(systemName: "eraser.fill")` with accent color background when active
- Tapping toggles `state.isEraserMode` and exits stamp mode (`state.isStampMode = false`)
- Remove eraser entry from `ToolsView`
- `DrawingState.isEraserMode` already exists — no model changes needed

---

## 7. Background: More Options

**Problem:** Only ~10 preset swatches; "Night" and "Black" look identical and confuse users.

**Fix:**
- Expand to ~24 preset swatches covering: warm neutrals, pastels, bright primaries, cool tones, one true black (labeled "Black"), one dark navy (labeled "Night Sky") with clearly different visual
- Add `ColorPicker` as the final item in the background color popover for fully custom color
- Remove or clearly differentiate "Night" (rename "Night Sky", make it noticeably dark blue vs pure black)

---

## 8. Pinch Gesture → Brush Resize

**Problem:** Resizing the brush requires navigating into the tools panel size slider — not ergonomic mid-drawing.

**Fix:** In `DrawingCanvasView.swift`:
- Add `MagnificationGesture` with `.simultaneously(with: dragGesture)`
- On gesture change, multiply current `state.brushSize` by the incremental scale delta
- Clamp result to existing min/max brush size bounds
- Reset gesture baseline on `.onEnded` so each pinch is relative

---

## 9. Hub Title: Triple-Tap to Rename

**Problem:** "Kids Fun Zone" title is hardcoded; parents may want to personalize it.

**Fix:** In `HubView.swift`:
- Default title text: `"Triple Tap here to change Name"`
- Load/save from `UserDefaults` key `"hubTitle"`
- Wrap the title `Text` in a `.onTapGesture(count: 3)` — shows an `Alert` with a `TextField`
- On confirm, save to `UserDefaults` and update displayed title
- On first launch (no saved value), show the default prompt text

---

## 10. Color Picker: System ColorPicker

**Approach:** System `ColorPicker` (available iOS 14+) — gives the user a color well that opens the native picker with wheel, grid, and slider tabs built in. Zero custom wheel code.

**Fix:** In `ColorPaletteView.swift`:
- Add a `ColorPicker("", selection: $state.selectedColor)` as the last item in the palette `HStack`
- Style it to match the swatch size (~36×36pt, rounded)
- On selection, `state.isEraserMode = false` and `state.isStampMode = false`
- No changes to `DrawingState` — `selectedColor` already exists

---

## 11. Opacity Slider: Per-Stroke

**Approach:** `brushOpacity` stored in `DrawingState`, baked into each stroke at draw time so undo works correctly.

**Data model changes:**
- Add `var brushOpacity: CGFloat = 1.0` to `DrawingState` (persisted via `UserDefaults`)
- Add `let opacity: CGFloat` to `Stroke` struct
- Update `DrawingState.beginStroke()` to pass `brushOpacity` into the new `Stroke`
- Update `CodableStroke` in `DrawingPersistence.swift` to encode/decode `opacity`

**Rendering:**
- In `DrawingCanvasView.swift`, apply `stroke.opacity` when rendering each stroke via `context.opacity` or wrapping in a `.opacity()` modifier group
- Eraser strokes always render at `opacity: 1.0` regardless of `brushOpacity`

**UI:**
- Add an opacity slider to `ToolsView` below the brush size slider
- Range: 0.1 – 1.0, step 0.05, labeled "Opacity"
- Displayed as a percentage or with a translucency preview swatch

---

## Files Changed

| File | Changes |
|---|---|
| `StampsView.swift` | Auto-select first stamp on category change |
| `Models.swift` | Hearts `sizeVariation` → 0.0; `Stroke` gets `opacity` field; `DrawingState` gets `brushOpacity` |
| `DrawingCanvasView.swift` | Eraser hard opacity; crayon enhancement; pinch gesture; apply stroke opacity |
| `TopToolbarView.swift` | Add eraser toggle button |
| `ToolsView.swift` | Remove eraser; add opacity slider |
| `ColorPaletteView.swift` | Add system ColorPicker |
| `ContentView.swift` | Background swatch expansion |
| `HubView.swift` | Triple-tap rename with UserDefaults |
| `DrawingPersistence.swift` | Add `opacity` to `CodableStroke` |

---

## Out of Scope (Flyout Plan)

The following items from the feedback session are deferred to the separate flyout architecture plan:
- Replacing sidebar panels with flyout popovers
- Portrait mode support
- Moving color picker and opacity into flyout UI
