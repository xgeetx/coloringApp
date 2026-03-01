# Spelling Fun Letter Slots Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add Scrabble-style target slots to Spelling Fun so children drag letters into the correct positions left-to-right to spell the word, with celebration on completion.

**Architecture:** Add `SlotState` model + `slotStates` array to `SpellingViewModel`. Modify `LetterStageView` to render a center slot row with scatter zones above/below. On drag-end, check proximity to next expected slot — snap if correct, shake + bounce-back if wrong. Confetti + bounce celebration when all slots filled.

**Tech Stack:** SwiftUI (iOS 15+), AVFoundation (existing TTS), UIKit haptics (existing)

**File:** `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift` (single file — entire package)

---

### Task 1: Add SlotState model and slot tracking to ViewModel

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift:48-70`

**Step 1: Add SlotState struct and celebration phase**

Add after the `StageTile` struct (line 62), before the `@Published` vars:

```swift
struct SlotState: Identifiable {
    let id = UUID()
    let expectedLetter: String
    let index: Int
    var filled: Bool = false
    var filledTileID: UUID? = nil
    var shaking: Bool = false
}
```

**Step 2: Add new published properties**

Add after `@Published var shuffleRequestToken = 0` (line 70):

```swift
@Published var slotStates: [SlotState] = []
@Published var nextSlotIndex: Int = 0
@Published var celebrating: Bool = false
```

**Step 3: Update `animateLettersIn` to also create slots**

In `animateLettersIn(word:stageSize:)` (line 99), add slot creation at the top after `stagedTiles = []`:

```swift
slotStates = letters.enumerated().map { index, letter in
    SlotState(expectedLetter: letter, index: index)
}
nextSlotIndex = 0
celebrating = false
```

**Step 4: Update `reset()` to clear slots**

In `reset()` (line 350), add:

```swift
slotStates = []
nextSlotIndex = 0
celebrating = false
```

**Step 5: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): add SlotState model and slot tracking properties"
```

---

### Task 2: Add slot snap detection and reject logic to ViewModel

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift` (ViewModel section)

**Step 1: Add `slotCenter` helper**

Add this method to `SpellingViewModel` after `updateTileRotation`:

```swift
func slotCenter(index: Int, slotCount: Int, stageSize: CGSize) -> CGPoint {
    let slotSize: CGFloat = 96
    let spacing: CGFloat = 8
    let totalWidth = CGFloat(slotCount) * slotSize + CGFloat(slotCount - 1) * spacing
    let startX = (stageSize.width - totalWidth) / 2 + slotSize / 2
    let x = startX + CGFloat(index) * (slotSize + spacing)
    let y = stageSize.height / 2
    return CGPoint(x: x, y: y)
}
```

**Step 2: Add `attemptSnap` method**

Add after `slotCenter`:

```swift
func attemptSnap(tileID: UUID, dropPosition: CGPoint, stageSize: CGSize) -> Bool {
    guard nextSlotIndex < slotStates.count else { return false }
    guard let tileIdx = stagedTiles.firstIndex(where: { $0.id == tileID }) else { return false }

    let tile = stagedTiles[tileIdx]
    let targetCenter = slotCenter(index: nextSlotIndex, slotCount: slotStates.count, stageSize: stageSize)
    let dx = dropPosition.x - targetCenter.x
    let dy = dropPosition.y - targetCenter.y
    let distance = sqrt(dx * dx + dy * dy)

    // Must be close enough to the next slot
    guard distance < 70 else { return false }

    // Must be the correct letter
    if tile.letter == slotStates[nextSlotIndex].expectedLetter {
        // Snap tile into slot
        slotStates[nextSlotIndex].filled = true
        slotStates[nextSlotIndex].filledTileID = tileID

        // Move tile to exact slot position (offset from stage center)
        let slotOffset = CGSize(
            width: targetCenter.x - stageSize.width / 2,
            height: targetCenter.y - stageSize.height / 2
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            stagedTiles[tileIdx].offset = slotOffset
            stagedTiles[tileIdx].rotation = .degrees(0)
        }

        nextSlotIndex += 1

        // Check for completion
        if nextSlotIndex == slotStates.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    self.celebrating = true
                }
            }
        }
        return true
    } else {
        // Wrong letter — trigger shake on the slot
        rejectSlot(index: nextSlotIndex)
        return false
    }
}

func rejectSlot(index: Int) {
    guard index < slotStates.count else { return }
    withAnimation(.default) {
        slotStates[index].shaking = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.slotStates[index].shaking = false
    }
}
```

**Step 3: Add bounce-back helper**

```swift
func bounceBackOffset(stageSize: CGSize) -> CGSize {
    let tileRadius: CGFloat = 52
    let slotRowCenter = stageSize.height / 2
    let exclusionBand: CGFloat = 80
    let xRange = max(10, stageSize.width / 2 - tileRadius)

    // Pick upper or lower zone randomly
    let goUp = Bool.random()
    let yMin: CGFloat
    let yMax: CGFloat
    if goUp {
        yMin = -(stageSize.height / 2 - tileRadius)
        yMax = -(exclusionBand)
    } else {
        yMin = exclusionBand
        yMax = stageSize.height / 2 - tileRadius
    }
    guard yMin < yMax else {
        return CGSize(width: CGFloat.random(in: -xRange...xRange), height: goUp ? -exclusionBand : exclusionBand)
    }

    return CGSize(
        width: CGFloat.random(in: -xRange...xRange),
        height: CGFloat.random(in: yMin...yMax)
    )
}
```

**Step 4: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): add slot snap detection, reject shake, and bounce-back logic"
```

---

### Task 3: Modify tile scattering to avoid center slot row

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift:144-155` (`randomOffsets` method)

**Step 1: Replace `randomOffsets` to exclude center band**

Replace the existing `randomOffsets` method:

```swift
private func randomOffsets(count: Int, stageSize: CGSize) -> [CGSize] {
    let tileRadius: CGFloat = 52
    let xRange = max(10, stageSize.width / 2 - tileRadius)
    let exclusionBand: CGFloat = 80

    return (0..<count).map { _ in
        let goUp = Bool.random()
        let yMin: CGFloat
        let yMax: CGFloat
        if goUp {
            yMin = -(stageSize.height / 2 - tileRadius)
            yMax = -exclusionBand
        } else {
            yMin = exclusionBand
            yMax = stageSize.height / 2 - tileRadius
        }
        let y: CGFloat
        if yMin < yMax {
            y = CGFloat.random(in: yMin...yMax)
        } else {
            y = goUp ? -exclusionBand : exclusionBand
        }
        return CGSize(
            width: CGFloat.random(in: -xRange...xRange),
            height: y
        )
    }
}
```

**Step 2: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): scatter tiles to upper/lower zones, avoid center slot row"
```

---

### Task 4: Add SlotRowView component

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift` (add new view struct)

**Step 1: Create SlotRowView**

Add after `LetterStageView` (after line 563):

```swift
struct SlotRowView: View {
    @ObservedObject var vm: SpellingViewModel
    let stageSize: CGSize

    private let slotSize: CGFloat = 96
    private let slotSpacing: CGFloat = 8

    var body: some View {
        HStack(spacing: slotSpacing) {
            ForEach(vm.slotStates) { slot in
                SlotCell(
                    slot: slot,
                    isNext: slot.index == vm.nextSlotIndex && !vm.celebrating,
                    slotSize: slotSize
                )
            }
        }
        .position(x: stageSize.width / 2, y: stageSize.height / 2)
    }
}

struct SlotCell: View {
    let slot: SpellingViewModel.SlotState
    let isNext: Bool
    let slotSize: CGFloat

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .strokeBorder(
                slot.filled ? Color.green : (isNext ? Color.purple : Color.gray.opacity(0.5)),
                style: slot.filled ? StrokeStyle(lineWidth: 3) : StrokeStyle(lineWidth: 3, dash: [8, 6]),
                antialiased: true
            )
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(slot.filled ? Color.green.opacity(0.15) : Color.white.opacity(0.4))
            )
            .frame(width: slotSize, height: slotSize)
            .scaleEffect(pulseScale)
            .offset(x: slot.shaking ? -6 : 0)
            .animation(
                slot.shaking
                    ? Animation.linear(duration: 0.08).repeatCount(5, autoreverses: true)
                    : .default,
                value: slot.shaking
            )
            .onAppear { updatePulse() }
            .onChange(of: isNext) { _ in updatePulse() }
    }

    private func updatePulse() {
        if isNext {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        } else {
            withAnimation(.default) {
                pulseScale = 1.0
            }
        }
    }
}
```

**Step 2: Integrate SlotRowView into LetterStageView**

Replace the `LetterStageView` body (lines 551-563) to include the slot row:

```swift
struct LetterStageView: View {
    @ObservedObject var vm: SpellingViewModel
    let stageSize: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.22))
                .padding(8)

            if !vm.slotStates.isEmpty {
                SlotRowView(vm: vm, stageSize: stageSize)
            }

            ForEach(vm.stagedTiles) { tile in
                if vm.slotStates.first(where: { $0.filledTileID == tile.id }) == nil {
                    DraggableTileView(vm: vm, tile: tile, stageSize: stageSize)
                }
            }

            // Render filled tiles on top of slots (non-draggable)
            ForEach(vm.stagedTiles) { tile in
                if vm.slotStates.first(where: { $0.filledTileID == tile.id }) != nil {
                    Text(tile.letter)
                        .font(.system(size: 68, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 96, height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(vm.tileColor(at: tile.colorIndex))
                                .shadow(color: vm.tileColor(at: tile.colorIndex).opacity(0.32), radius: 4, x: 0, y: 2)
                        )
                        .rotationEffect(.degrees(0))
                        .offset(x: tile.offset.width, y: tile.offset.height)
                        .scaleEffect(vm.celebrating ? 1.15 : 1.0)
                        .animation(
                            vm.celebrating
                                ? Animation.spring(response: 0.3, dampingFraction: 0.5)
                                    .delay(Double(tile.colorIndex) * 0.1)
                                : .default,
                            value: vm.celebrating
                        )
                }
            }
        }
        .clipped()
    }
}
```

**Step 3: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): add SlotRowView with pulse, shake, and filled states"
```

---

### Task 5: Wire drag-end to slot snap detection

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift:607-633` (`DraggableTileView` drag gesture)

**Step 1: Replace the `dragGesture.onEnded` handler**

Replace the `.onEnded` closure in `DraggableTileView.dragGesture` (around line 620):

```swift
.onEnded { value in
    hasSpokeThisDrag = false
    isDragging = false
    vm.emitDragEndHaptic()

    let finalOffset = CGSize(
        width: tile.offset.width + value.translation.width,
        height: tile.offset.height + value.translation.height
    )
    // Convert offset to position (offsets are relative to stage center)
    let dropPosition = CGPoint(
        x: stageSize.width / 2 + finalOffset.width,
        y: stageSize.height / 2 + finalOffset.height
    )

    let snapped = vm.attemptSnap(tileID: tile.id, dropPosition: dropPosition, stageSize: stageSize)
    if !snapped {
        // Check if was near a slot (rejected) — bounce back away from center
        let slotRowY = stageSize.height / 2
        let nearSlotRow = abs(dropPosition.y - slotRowY) < 80
        if nearSlotRow && !vm.slotStates.isEmpty {
            let bounced = vm.bounceBackOffset(stageSize: stageSize)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                vm.updateTileOffset(id: tile.id, newOffset: bounced, stageSize: stageSize)
            }
        } else {
            vm.updateTileOffset(id: tile.id, newOffset: finalOffset, stageSize: stageSize)
        }
    }
}
```

**Step 2: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): wire drag-end to slot snap with bounce-back on reject"
```

---

### Task 6: Add confetti celebration view

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift` (add ConfettiView + integrate)

**Step 1: Add ConfettiView**

Add before the `#Preview` section:

```swift
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var started = false

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        var y: CGFloat
        let size: CGFloat
        let rotation: Double
        let speed: CGFloat
    }

    private let colors: [Color] = [
        Color(r: 255, g: 100, b: 120),
        Color(r: 255, g: 200, b: 60),
        Color(r: 80, g: 200, b: 120),
        Color(r: 60, g: 160, b: 255),
        Color(r: 200, g: 80, b: 240),
        Color(r: 255, g: 140, b: 60)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: p.size * 0.25)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.6)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                }
            }
            .onAppear {
                spawnParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        particles = (0..<45).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -size.height * 0.3 ... -20),
                size: CGFloat.random(in: 8...16),
                rotation: Double.random(in: 0...360),
                speed: CGFloat.random(in: 200...500)
            )
        }

        // Animate particles falling
        withAnimation(.easeIn(duration: 2.5)) {
            for idx in particles.indices {
                particles[idx].y += CGFloat.random(in: 600...900)
            }
        }

        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            particles = []
        }
    }
}
```

**Step 2: Add confetti overlay to SpellingStageLayout**

In `SpellingStageLayout` body, wrap the existing VStack in a ZStack and add confetti:

```swift
var body: some View {
    ZStack {
        VStack(spacing: 0) {
            LetterStageView(vm: vm, stageSize: stageSize)
                .frame(width: stageSize.width, height: stageSize.height)

            KeyboardDisplayPanel(word: word)
                .frame(width: containerSize.width, height: containerSize.height * 0.45)
        }

        if vm.celebrating {
            ConfettiView()
        }
    }
    .onAppear { vm.animateLettersIn(word: word, stageSize: stageSize) }
    .onChange(of: word) { newWord in
        vm.animateLettersIn(word: newWord, stageSize: stageSize)
    }
    .onChange(of: vm.shuffleRequestToken) { _ in
        vm.shuffleTiles(stageSize: stageSize)
    }
}
```

**Step 3: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "feat(spelling): add confetti celebration on word completion"
```

---

### Task 7: Handle duplicate letters and edge cases

**Files:**
- Modify: `Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift`

**Step 1: Fix duplicate letter matching**

The current `attemptSnap` compares `tile.letter == slotStates[nextSlotIndex].expectedLetter`. For words with duplicate letters (e.g., "HELLO"), any matching letter tile should be accepted for the next slot if it has the right letter. This already works correctly — the check is "does this tile have the letter the next slot expects", not "is this tile the specific one assigned to this slot". No code change needed, just verify.

**Step 2: Disable shuffle for filled tiles**

Update `shuffleTiles` to only shuffle unfilled tiles:

```swift
func shuffleTiles(stageSize: CGSize) {
    let unfilledIDs = Set(slotStates.filter { !$0.filled }.compactMap { _ -> UUID? in nil })
    let unfilledIndices = stagedTiles.indices.filter { idx in
        !slotStates.contains(where: { $0.filledTileID == stagedTiles[idx].id })
    }
    guard !unfilledIndices.isEmpty else { return }
    let shuffledOffsets = (0..<unfilledIndices.count).map { _ in bounceBackOffset(stageSize: stageSize) }
    for (i, tileIdx) in unfilledIndices.enumerated() {
        withAnimation(.spring(response: 0.75, dampingFraction: 0.80)) {
            stagedTiles[tileIdx].offset = shuffledOffsets[i]
        }
    }
}
```

**Step 3: Commit**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "fix(spelling): shuffle only unfilled tiles, handle duplicate letters"
```

---

### Task 8: Build verification

**Step 1: Push and build on Mac**

```bash
git push
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`

**Step 2: Fix any build errors**

If errors occur, fix in WSL, commit, push, rebuild. Common issues:
- iOS 15 compat: no two-param `.onChange`, no `presentationDetents`
- `strokeBorder` needs `InsettableShape` — `RoundedRectangle` qualifies
- Missing `import` — everything is in one file, should be fine

**Step 3: Final commit if fixes needed**

```bash
git add Packages/SpellingFun/Sources/SpellingFun/SpellingView.swift
git commit -m "fix(spelling): resolve build errors for letter slots"
```
