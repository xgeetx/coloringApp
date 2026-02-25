# Spelling Fun Complete Implementation Plan (SwiftUI)

**Goal:** Build and ship a SwiftUI spelling app that supports the full merged scope:
- Voice-first spelling flow
- Confirm/edit word flow
- Auto-animated letter tiles
- Drag-to-speak interaction
- Shuffle action
- Typed fallback input
- Accessibility and haptics
- Rotation gesture support (post-stability)

**Primary Files:**
- `ColoringApp/SpellingView.swift`
- `ColoringApp/AppRegistry.swift`
- `ColoringFun.xcodeproj/project.pbxproj`

**Constraints:**
- iOS 15+
- SwiftUI + Apple frameworks only (`Speech`, `AVFoundation`)
- No third-party dependencies

---

## Delivery Strategy

Ship in 3 phases to reduce risk and keep quality high:

1. **Phase 1 (MVP):** Voice -> confirm -> spelling stage with drag-to-speak.
2. **Phase 2 (Reliability + Replay):** Shuffle + typed fallback + accessibility/haptics.
3. **Phase 3 (Advanced Interaction):** Rotation gesture and gesture conflict hardening.

Each phase ends with a simulator build and checklist pass.

---

## Architecture

### State Machine
`SpellingPhase`:
- `.idle`
- `.listening`
- `.confirm(word: String)`
- `.spelling(word: String)`

### View Model
`@MainActor final class SpellingViewModel: ObservableObject`
- Input/flow state:
  - `phase`
  - `transcript`
  - `permissionDenied`
  - `manualWordInput`
- Stage state:
  - `stagedTiles: [StageTile]`
  - optional `stageBounds` cache for shuffle/rotation clamping
- Services:
  - `SFSpeechRecognizer`
  - `AVAudioEngine`
  - `AVSpeechSynthesizer`

### Tile Model
`StageTile` fields:
- `id: UUID`
- `letter: String`
- `colorIndex: Int`
- `offset: CGSize`
- `rotation: Angle`
- `appeared: Bool`

### Core Methods
- `requestAndStart()`
- `startRecording()` / `stopRecording()`
- `extractWord(from:)`
- `normalizeWord(_:)`
- `animateLettersIn(word:stageSize:)`
- `updateTileOffset(id:newOffset:)`
- `updateTileRotation(id:newRotation:)`
- `shuffleTiles(stageSize:)`
- `speakLetter(_:)`
- `reset()`

---

## Phase 1: Core App (MVP)

### Task 1: Create `SpellingView.swift` with complete MVP flow

**Build:**
- Root view with gradient background and top bar.
- `MicPromptView`: start/stop recording, permission messaging.
- `ConfirmWordView`: shows detected word with `Try Again` and `Spell It!`.
- `SpellingStageLayout`: top stage + read-only keyboard panel.
- `LetterStageView` + `DraggableTileView`: drag tile, speak letter once per drag.

**Acceptance:**
- Saying "how do you spell cat" leads to confirm `CAT`.
- Saying a standalone word like "flower" works.
- Confirming starts auto letter launch animation.
- Dragging tile speaks letter and updates final position.

### Task 2: Register new view in Xcode project

**Build:**
- Add `SpellingView.swift` to `project.pbxproj` in all required sections:
  - `PBXBuildFile`
  - `PBXFileReference`
  - `PBXGroup`
  - `PBXSourcesBuildPhase`

**Acceptance:**
- `grep "SpellingView" ColoringFun.xcodeproj/project.pbxproj` returns all expected entries.
- No "cannot find SpellingView in scope" build error.

### Task 3: Activate hub tile

**Build:**
- Replace `app3` placeholder in `AppRegistry.swift` with:
  - `id: "spelling"`
  - `displayName: "Spelling Fun"`
  - subtitle/icon/tile color
  - `makeRootView: { AnyView(SpellingView()) }`

**Acceptance:**
- Tile appears in hub.
- Tile opens `SpellingView` full-screen.

### Task 4: Build + smoke test

**Build:**
- Build on simulator.

**Acceptance checklist:**
- [ ] Mic flow works from idle/listening.
- [ ] Confirm screen appears when word extracted.
- [ ] Stage animation runs once per new word.
- [ ] Drag-to-speak works on repeated drags.
- [ ] Home + New Word controls return to expected states.

---

## Phase 2: Reliability + Replay

### Task 5: Add Shuffle action

**Build:**
- Show `Shuffle` action in top bar during `.spelling`.
- `shuffleTiles(stageSize:)` reassigns random in-bounds tile offsets with spring animation.

**Acceptance:**
- [ ] Tiles scatter and remain on-screen.
- [ ] Drag/speak still works after shuffle.

### Task 6: Add typed fallback input on confirm

**Build:**
- Add `TextField` in `ConfirmWordView` bound to `manualWordInput`.
- Pre-fill field with detected word when entering `.confirm`.
- Add `Use Typed Word` CTA.
- Validation: `A-Z` only, length `2...20`, uppercase normalization.

**Acceptance:**
- [ ] User can fix misheard words and proceed.
- [ ] Invalid input is rejected with clear inline feedback.
- [ ] Manual entry works even with empty transcript.

### Task 7: Accessibility + haptics

**Build:**
- VoiceOver labels/hints for:
  - mic button
  - home/new word/shuffle controls
  - each letter tile
- Dynamic type-friendly control sizes.
- Haptics:
  - light impact on drag start
  - soft impact on drag end
- Verify high contrast for key labels/buttons.

**Acceptance:**
- [ ] Controls are meaningfully announced by VoiceOver.
- [ ] Drag events produce haptic feedback.
- [ ] No low-contrast regressions in core screens.

---

## Phase 3: Rotation Support (Advanced)

### Task 8: Add rotation gesture per tile

**Build:**
- Add `rotation` field to tile model if not already present.
- Extend tile interaction to combine:
  - drag
  - rotation gesture
- Update view transform with `rotationEffect(tile.rotation)`.

**Gesture conflict handling:**
- Prioritize drag when single-finger gesture detected.
- Apply rotation on two-finger rotate gesture.
- Preserve drag-to-speak behavior on drag begin.

**Acceptance:**
- [ ] Tile can rotate smoothly without breaking drag.
- [ ] Rotation persists after releasing gesture.
- [ ] No jitter/teleport under rapid gesture changes.

### Task 9: Stabilization pass

**Build:**
- Clamp positions to reasonable stage bounds.
- Guard against overlapping animation + gesture updates.
- Resolve any stale state when switching words quickly.

**Acceptance:**
- [ ] No crashes during rapid drag/rotate/shuffle interactions.
- [ ] New word always resets tile transforms cleanly.

---

## Testing Matrix

### Functional
- [ ] Voice phrase extraction: "spell cat", "how do you spell flower", "flower".
- [ ] Confirm -> spell transition works every time.
- [ ] Typed fallback accepts valid input and rejects invalid input.
- [ ] Shuffle works repeatedly.
- [ ] Rotate + drag both work after shuffle.

### UX
- [ ] Letter launch animation is staggered and readable.
- [ ] Keyboard panel highlights letters in current word.
- [ ] Top bar actions visible only in relevant phases.

### Resilience
- [ ] Permission denied state is non-crashing and recoverable.
- [ ] Rapid tapping on mic/start/stop does not break state machine.
- [ ] Repeated word sessions do not leak stale tile state.

### Accessibility
- [ ] VoiceOver path for complete flow.
- [ ] Touch targets are comfortably tappable for children.
- [ ] Haptics are present but not excessive.

---

## Implementation Order (Exact)

1. Task 1 (MVP view + model)
2. Task 2 (pbxproj wiring)
3. Task 3 (hub registration)
4. Task 4 (MVP verification)
5. Task 5 (shuffle)
6. Task 6 (typed fallback)
7. Task 7 (a11y + haptics)
8. Task 8 (rotation)
9. Task 9 (stabilization)
10. Full testing matrix pass

---

## Definition of Done

- All 9 tasks completed.
- Simulator build succeeds with zero compile errors.
- Entire testing matrix passes.
- App supports voice + typed word entry, drag + speak, shuffle, and rotation in a stable manner.
- Hub tile integration is complete and production-ready.
