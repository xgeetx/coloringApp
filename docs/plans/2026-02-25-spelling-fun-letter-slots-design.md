# Spelling Fun — Letter Slots (Scrabble Board)

**Date:** 2026-02-25
**Status:** Approved

## Summary

Add a row of target slots to Spelling Fun so letters have a purpose: drag them into the correct slots in left-to-right order to spell the word. Transforms the app from free-form letter play into a spelling puzzle.

## Layout

The stage area (top 55% of screen) splits into three zones:

- **Upper scatter zone** (~40% of stage height) — tiles scatter here
- **Center slot row** — horizontal row of square slots, vertically centered in stage
- **Lower scatter zone** (~40% of stage height) — tiles scatter here too

The keyboard display panel remains at the bottom 45%, unchanged.

## Slot Appearance

- **Empty**: rounded square with dashed border, translucent white fill (`Color.white.opacity(0.4)`)
- **Next expected**: gentle pulse animation (scale 1.0 ↔ 1.06) to guide the child
- **Filled**: tile snaps into slot, border becomes solid, background matches tile color
- Slot size matches tile size (~96pt) with slight padding between slots

## Interaction Rules

1. **Strict left-to-right order**: only the next unfilled slot accepts a letter
2. **Snap detection**: when a dragged tile's center is within ~60pt of the next expected slot's center, it snaps into place
3. **Correct letter + correct slot**: tile animates into slot position, haptic feedback, slot fills
4. **Wrong letter or wrong slot**: slot shakes horizontally (3-cycle wobble), tile bounces back to a random scatter position biased 80pt+ away from the center slot row
5. Letters still speak via TTS on drag start (existing behavior preserved)

## Tile Scattering

- `randomOffsets` must avoid the center slot row — scatter positions stay in upper/lower zones
- Bounce-back positions also biased away from center row (minimum 80pt vertical clearance from slot row center)

## Celebration (all slots filled)

- **Confetti**: 40-50 colorful circles/squares with gravity-based fall animation, 2-3 seconds
- **Tile bounce**: each placed tile does a scale-up/down wiggle in sequence (0.1s stagger per tile)
- **No TTS** for celebration (performance concern)
- After ~3 seconds, show prompt or auto-reset flow

## What Stays the Same

- Voice input flow (mic → word extraction)
- Keyboard display panel at bottom with highlighted letters
- Top bar (Home, Shuffle, New Word buttons)
- Tile colors, sizing, rotation gesture
- TTS on drag start (speak letter)
- Haptics on drag start/end

## What Changes

- `SpellingViewModel` gains: `slotStates: [SlotState]` array, `nextSlotIndex: Int`, slot snap logic, celebration state
- `LetterStageView` renders slot row in center + scatter tiles around it
- `randomOffsets` / bounce-back exclude the center slot row band
- `DraggableTileView.onEnded` checks proximity to next slot → snap or reject
- New: `SlotView` component (dashed border, pulse, filled states)
- New: `ConfettiView` for celebration animation
- New: `CelebrationPhase` or flag on the phase enum
