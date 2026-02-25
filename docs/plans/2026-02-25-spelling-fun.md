# Spelling Fun Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Build a voice-driven spelling app for the 3rd hub tile — say a word, letters automatically animate out of the keyboard and land on the stage, then the child drags letters around and hears each one spoken aloud.

**Architecture:** Single `SpellingView.swift`. State machine: `.idle → .listening → .confirm(word) → .spelling(word)`. On entering `.spelling`, all letters for the word auto-animate in a staggered sequence — each tile springs up from the keyboard zone to a scattered position on the stage (no user action required). The keyboard is a **read-only visual** at the bottom (not interactive), with the word's letters highlighted in purple so kids see the connection. The only interaction is **drag a tile → hear the letter spoken** (fires once per drag gesture via `onChanged` guard). Kids can scatter, stack, rearrange letters freely.

**Tech Stack:** SwiftUI, SFSpeechRecognizer (iOS 15+), AVSpeechSynthesizer, DragGesture, spring animations. No new dependencies.

**Merged Scope Decision (MVP vs Follow-up):**
- Keep current MVP exactly focused on: voice input, confirm word, auto-animate letters, drag-to-speak.
- Add `Shuffle` as first follow-up because it is low-risk and high replay value.
- Defer `Rotate` to later; it adds gesture complexity and higher QA cost.
- Add typed fallback next (manual keyboard word entry/edit on confirm screen) for reliability when speech fails.
- Add accessibility polish next (labels, haptics, contrast checks).

---

## UUID Reference (copy-paste into pbxproj)

```
PBXBuildFile   : E6F6A7B8C9D0E1F2A3B4C5D6
PBXFileRef     : F7A7B8C9D0E1F2A3B4C5D6E7
```

---

### Task 1: Create `SpellingView.swift`

**Files:**
- Create: `ColoringApp/SpellingView.swift`

**Step 1: Create the file with full implementation**

```swift
import SwiftUI
import Speech
import AVFoundation

// MARK: - Root View

struct SpellingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SpellingViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(r: 200, g: 240, b: 255),
                    Color(r: 255, g: 220, b: 240),
                    Color(r: 255, g: 245, b: 200),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                SpellingTopBar(vm: vm, onHome: { dismiss() })
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                GeometryReader { geo in
                    switch vm.phase {
                    case .idle, .listening:
                        MicPromptView(vm: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .confirm(let word):
                        ConfirmWordView(vm: vm, word: word)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .spelling(let word):
                        SpellingStageLayout(vm: vm, word: word, containerSize: geo.size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear { vm.stopRecording() }
    }
}

// MARK: - View Model

@MainActor
final class SpellingViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case confirm(String)
        case spelling(String)
    }

    @Published var phase: Phase = .idle
    @Published var transcript: String = ""
    @Published var permissionDenied = false
    @Published var stagedTiles: [StageTile] = []

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    let synthesizer = AVSpeechSynthesizer()

    struct StageTile: Identifiable {
        let id = UUID()
        let letter: String
        let colorIndex: Int
        var offset: CGSize = .zero
        var appeared: Bool = false
    }

    let tileColors: [Color] = [
        Color(r: 255, g: 100, b: 120),
        Color(r: 255, g: 160, b: 60),
        Color(r: 80,  g: 180, b: 100),
        Color(r: 60,  g: 140, b: 230),
        Color(r: 160, g: 80,  b: 220),
        Color(r: 230, g: 80,  b: 180),
    ]

    func tileColor(at index: Int) -> Color { tileColors[index % tileColors.count] }

    // MARK: - Auto animation

    /// Called once when SpellingStageLayout appears.
    /// Creates all tiles starting below stage (keyboard zone) and springs them
    /// to scattered final positions with staggered timing.
    func animateLettersIn(word: String, stageSize: CGSize) {
        guard stagedTiles.isEmpty else { return }
        let letters = word.map { String($0) }
        for (i, letter) in letters.enumerated() {
            let finalX = CGFloat.random(in: -stageSize.width * 0.38 ... stageSize.width * 0.38)
            let finalY = CGFloat.random(in: -stageSize.height * 0.35 ... stageSize.height * 0.35)
            // Start below the stage (visually inside the keyboard panel)
            let startX = CGFloat.random(in: -20...20)
            let startY = stageSize.height * 0.7
            let tile = StageTile(
                letter: letter,
                colorIndex: i % tileColors.count,
                offset: CGSize(width: startX, height: startY),
                appeared: false
            )
            stagedTiles.append(tile)
            let tileID = tile.id
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                if let idx = self.stagedTiles.firstIndex(where: { $0.id == tileID }) {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.58)) {
                        self.stagedTiles[idx].offset = CGSize(width: finalX, height: finalY)
                        self.stagedTiles[idx].appeared = true
                    }
                }
            }
        }
    }

    func updateTileOffset(id: UUID, newOffset: CGSize) {
        if let idx = stagedTiles.firstIndex(where: { $0.id == id }) {
            stagedTiles[idx].offset = newOffset
        }
    }

    func speakLetter(_ letter: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: letter)
        utterance.rate = 0.4
        utterance.pitchMultiplier = 1.3
        synthesizer.speak(utterance)
    }

    // MARK: - Word extraction

    func extractWord(from transcript: String) -> String? {
        let lower = transcript.lowercased()
        for marker in ["spell ", "spelling "] {
            if let range = lower.range(of: marker) {
                let rest = String(lower[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let word = rest.components(separatedBy: .whitespaces).first ?? ""
                if word.count >= 2 { return word.uppercased() }
            }
        }
        let fillers: Set<String> = ["a","the","an","i","um","uh","and","or","so","like","it","is","was","to","do","how","what","can","you"]
        let words = lower.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 && !fillers.contains($0) }
        return words.last.map { $0.uppercased() }
    }

    // MARK: - Speech recognition

    func requestAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard status == .authorized else { self?.permissionDenied = true; return }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor [weak self] in
                        if granted { self?.startRecording() } else { self?.permissionDenied = true }
                    }
                }
            }
        }
    }

    func startRecording() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        let engine = AVAudioEngine()
        audioEngine = engine
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                    let word = self.extractWord(from: self.transcript) ?? ""
                    self.phase = word.count >= 2 ? .confirm(word) : .idle
                }
            }
        }

        engine.prepare()
        do { try engine.start(); phase = .listening } catch { stopRecording() }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil; recognitionRequest = nil; recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        transcript = ""
        stagedTiles = []
        phase = .idle
    }
}

// MARK: - Top Bar

struct SpellingTopBar: View {
    @ObservedObject var vm: SpellingViewModel
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SpellingBarButton(icon: "house.fill", label: "Home", color: .indigo) { onHome() }
            Spacer()
            Text(titleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            if case .spelling = vm.phase {
                SpellingBarButton(icon: "arrow.counterclockwise", label: "New Word", color: .orange) { vm.reset() }
            } else {
                Color.clear.frame(width: 72, height: 52)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.1), radius: 4))
    }

    private var titleText: String {
        switch vm.phase {
        case .idle:               return "✏️ Spelling Fun!"
        case .listening:          return "🎤 Listening…"
        case .confirm(let word):  return "📝 \(word)?"
        case .spelling(let word): return word
        }
    }
}

struct SpellingBarButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: { action(); pressed = true; DispatchQueue.main.asyncAfter(deadline: .now()+0.15){ pressed=false } }) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(color)
            .frame(width: 72, height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Mic Prompt

struct MicPromptView: View {
    @ObservedObject var vm: SpellingViewModel
    @State private var pulse = false

    private var isListening: Bool { if case .listening = vm.phase { return true }; return false }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Button(action: {
                if isListening {
                    vm.stopRecording()
                    let word = vm.extractWord(from: vm.transcript) ?? ""
                    vm.phase = word.count >= 2 ? .confirm(word) : .idle
                } else {
                    vm.requestAndStart()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red : Color.purple)
                        .frame(width: 160, height: 160)
                        .shadow(color: (isListening ? Color.red : Color.purple).opacity(0.4), radius: pulse ? 40 : 20)
                        .scaleEffect(pulse ? 1.06 : 1.0)
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 70)).foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = isListening } }
            .onChange(of: isListening) { _, _ in withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = isListening } }

            Group {
                if isListening && !vm.transcript.isEmpty {
                    Text(vm.transcript)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        .padding(.horizontal, 40).transition(.opacity)
                } else {
                    Text(isListening ? "Tap to stop" : "Say a word!")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.purple)
                }
            }
            .animation(.default, value: vm.transcript)

            if vm.permissionDenied {
                Label("Microphone access needed — check Settings", systemImage: "mic.slash")
                    .font(.subheadline).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

// MARK: - Confirm Word

struct ConfirmWordView: View {
    @ObservedObject var vm: SpellingViewModel
    let word: String
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("Did you say…")
                .font(.system(size: 28, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            Text(word)
                .font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(Color.purple)
            HStack(spacing: 24) {
                Button(action: { vm.reset() }) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.7)))
                }
                .buttonStyle(.plain)
                Button(action: { vm.phase = .spelling(word) }) {
                    Label("Spell It! ✨", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 36).padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.purple)
                            .shadow(color: .purple.opacity(0.4), radius: 8, y: 4))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Spelling Stage Layout

/// Top 55%: draggable letter tile stage.
/// Bottom 45%: read-only keyboard display (letters in the word highlighted).
struct SpellingStageLayout: View {
    @ObservedObject var vm: SpellingViewModel
    let word: String
    let containerSize: CGSize

    private var stageSize: CGSize {
        CGSize(width: containerSize.width, height: containerSize.height * 0.55)
    }

    var body: some View {
        VStack(spacing: 0) {
            LetterStageView(vm: vm, stageSize: stageSize)
                .frame(width: stageSize.width, height: stageSize.height)

            KeyboardDisplayPanel(word: word)
                .frame(width: containerSize.width, height: containerSize.height * 0.45)
        }
        .onAppear {
            vm.animateLettersIn(word: word, stageSize: stageSize)
        }
    }
}

// MARK: - Letter Stage

struct LetterStageView: View {
    @ObservedObject var vm: SpellingViewModel
    let stageSize: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.22))
                .padding(8)

            ForEach(vm.stagedTiles) { tile in
                DraggableTileView(vm: vm, tile: tile)
            }
        }
        .clipped()
    }
}

// MARK: - Draggable Tile
//
// Interaction: pick up (drag) a tile → letter is spoken once per gesture.
// The tile also scales up slightly while being dragged for physical feedback.

struct DraggableTileView: View {
    @ObservedObject var vm: SpellingViewModel
    let tile: SpellingViewModel.StageTile

    @GestureState private var dragDelta: CGSize = .zero
    @State private var hasSpokeThisDrag = false
    @State private var isDragging = false

    var body: some View {
        Text(tile.letter)
            .font(.system(size: 68, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(vm.tileColor(at: tile.colorIndex))
                    .shadow(color: vm.tileColor(at: tile.colorIndex).opacity(isDragging ? 0.7 : 0.45),
                            radius: isDragging ? 18 : 8, x: 0, y: isDragging ? 8 : 4)
            )
            .scaleEffect(isDragging ? 1.18 : (tile.appeared ? 1.0 : 0.05))
            .opacity(tile.appeared ? 1 : 0)
            .offset(
                x: tile.offset.width + dragDelta.width,
                y: tile.offset.height + dragDelta.height
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragDelta) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { _ in
                        // Speak letter once when drag begins; reset on release
                        if !hasSpokeThisDrag {
                            hasSpokeThisDrag = true
                            isDragging = true
                            vm.speakLetter(tile.letter)
                        }
                    }
                    .onEnded { value in
                        hasSpokeThisDrag = false
                        isDragging = false
                        vm.updateTileOffset(id: tile.id, newOffset: CGSize(
                            width: tile.offset.width + value.translation.width,
                            height: tile.offset.height + value.translation.height
                        ))
                    }
            )
    }
}

// MARK: - Keyboard Display Panel (read-only)
//
// Shows all 26 letters in ABC order, 3 rows.
// Letters present in the current word are highlighted in purple.
// NOT interactive — purely visual, reinforces letter recognition.

struct KeyboardDisplayPanel: View {
    let word: String

    private let rows: [[String]] = [
        ["A","B","C","D","E","F","G","H","I"],
        ["J","K","L","M","N","O","P","Q","R"],
        ["S","T","U","V","W","X","Y","Z"],
    ]

    private var wordLetters: Set<String> { Set(word.map { String($0) }) }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 5) {
                    ForEach(rows[rowIdx], id: \.self) { letter in
                        let inWord = wordLetters.contains(letter)
                        Text(letter)
                            .font(.system(size: 22, weight: inWord ? .black : .regular, design: .rounded))
                            .foregroundStyle(inWord ? Color.purple : Color.secondary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(inWord ? Color.purple.opacity(0.14) : Color.white.opacity(0.55))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    SpellingView()
}
```

**Step 2: Verify the file was created**

```bash
ls -la ColoringApp/SpellingView.swift
```
Expected: file exists, non-zero size.

**Step 3: Commit**

```bash
git add ColoringApp/SpellingView.swift
git commit -m "feat: add SpellingView — auto letter animation + drag-to-speak"
```

---

### Task 2: Register `SpellingView.swift` in `project.pbxproj`

All 4 insertions required — missing any one causes "cannot find SpellingView in scope" build error.

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj`

**Step 1: Add PBXBuildFile entry**

After the line containing `D5E5F6A7B8C9D0E1F2A3B4C5 /* KidBrushBuilderView.swift in Sources */`, insert:
```
		E6F6A7B8C9D0E1F2A3B4C5D6 /* SpellingView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7A7B8C9D0E1F2A3B4C5D6E7 /* SpellingView.swift */; };
```

**Step 2: Add PBXFileReference entry**

After the line containing `C4D4E5F6A7B8C9D0E1F2A3B4 /* KidBrushBuilderView.swift */` (in the PBXFileReference section), insert:
```
		F7A7B8C9D0E1F2A3B4C5D6E7 /* SpellingView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpellingView.swift; sourceTree = "<group>"; };
```

**Step 3: Add to PBXGroup children**

After the line containing `C4D4E5F6A7B8C9D0E1F2A3B4 /* KidBrushBuilderView.swift */,` (in the PBXGroup section), insert:
```
				F7A7B8C9D0E1F2A3B4C5D6E7 /* SpellingView.swift */,
```

**Step 4: Add to PBXSourcesBuildPhase**

After the line containing `D5E5F6A7B8C9D0E1F2A3B4C5 /* KidBrushBuilderView.swift in Sources */,`, insert:
```
				E6F6A7B8C9D0E1F2A3B4C5D6 /* SpellingView.swift in Sources */,
```

**Step 5: Verify all 4 references present**

```bash
grep "SpellingView" ColoringFun.xcodeproj/project.pbxproj
```
Expected: exactly 4 lines.

**Step 6: Commit**

```bash
git add ColoringFun.xcodeproj/project.pbxproj
git commit -m "feat: register SpellingView.swift in pbxproj (all 4 sections)"
```

---

### Task 3: Activate 3rd tile in `AppRegistry.swift`

**Files:**
- Modify: `ColoringApp/AppRegistry.swift`

**Step 1: Replace the `app3` placeholder**

Find:
```swift
        .placeholder(id: "app3", icon: "🧩", displayName: "Puzzle Play"),
```

Replace with:
```swift
        MiniAppDescriptor(
            id: "spelling",
            displayName: "Spelling Fun",
            subtitle: "Say a Word!",
            icon: "✏️",
            tileColor: Color(r: 200, g: 180, b: 255),
            isAvailable: true,
            makeRootView: { AnyView(SpellingView()) }
        ),
```

**Step 2: Verify syntax — confirm `apps` array still closes with `]` and all commas are correct.**

**Step 3: Commit**

```bash
git add ColoringApp/AppRegistry.swift
git commit -m "feat: activate Spelling Fun as 3rd hub tile"
```

---

### Task 4: Build on simulator and verify

**Step 1: Build on Mac**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

If Mac has local changes first run: `ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash && git pull"`.

Expected: `BUILD SUCCEEDED`, no `error:` lines.

**Step 2: Push**

```bash
git push
```

---

## Testing Checklist

- [ ] Hub tile shows ✏️ Spelling Fun (lavender, "Say a Word!" subtitle)
- [ ] Tapping tile opens SpellingView full screen
- [ ] Large purple mic button centred; pulses red when recording
- [ ] Say "how do you spell cat" → confirm screen shows CAT
- [ ] Say just "flower" → confirm shows FLOWER
- [ ] Tap "Spell It!" → keyboard display appears at bottom with C, A, T highlighted purple
- [ ] All word letters auto-animate up from keyboard zone to stage (staggered, no user input)
- [ ] Non-word letters on keyboard are dim/unemphasised
- [ ] Drag a tile → letter spoken aloud, tile lifts with shadow
- [ ] Drag same tile again → letter spoken again
- [ ] Multiple tiles independently draggable and stackable
- [ ] "New Word" → stage cleared, back to mic screen
- [ ] Home → back to Hub
- [ ] No crash on rapid drags

---

## Phase 2 Enhancements (Merged from Product Design)

These are intentionally sequenced after MVP ship so we preserve fast delivery and stable behavior.

### Task 5: Add `Shuffle` Action (Priority: High)

**Purpose:** Increase replay without requiring a new spoken word.

**Files:**
- Modify: `ColoringApp/SpellingView.swift`

**Implementation:**
- Add a `Shuffle` button to `SpellingTopBar` when in `.spelling`.
- In `SpellingViewModel`, add `shuffleTiles(stageSize:)`:
  - Reassign each tile to a random in-bounds offset.
  - Animate using spring response similar to initial letter launch.
- Keep drag behavior unchanged.

**Acceptance:**
- [ ] Tap `Shuffle` scatters all currently visible tiles.
- [ ] Tiles remain draggable and speak letters on drag after shuffling.
- [ ] No tile animates off-screen.

### Task 6: Add Typed Fallback Input (Priority: High)

**Purpose:** Ensure app still works when speech recognition misses the word.

**Files:**
- Modify: `ColoringApp/SpellingView.swift`

**Implementation:**
- Add `@Published var manualWordInput: String = ""` in view model.
- On `ConfirmWordView`, include a text field pre-filled with detected word.
- Add "Use Typed Word" action that validates and transitions to `.spelling`.
- Validation rules:
  - letters A-Z only
  - length 2...20
  - stored/displayed uppercase

**Acceptance:**
- [ ] User can edit misheard word and proceed.
- [ ] Input rejects invalid symbols/numbers.
- [ ] Manual flow works even if transcript is empty.

### Task 7: Accessibility and Feedback Polish (Priority: Medium)

**Purpose:** Improve usability for kids and caregivers with assistive needs.

**Files:**
- Modify: `ColoringApp/SpellingView.swift`

**Implementation:**
- Add accessibility labels/hints to mic, top-bar buttons, and letter tiles.
- Add haptic feedback:
  - light impact at drag start
  - soft impact at drag end
- Verify text contrast for purple elements over gradient/material surfaces.

**Acceptance:**
- [ ] VoiceOver reads all major controls with meaningful labels.
- [ ] Dragging tiles provides haptic feedback.
- [ ] No obvious low-contrast labels in primary flows.

### Deferred: Rotation Gestures (Priority: Low, Post-Phase 2)

`Rotate` remains intentionally out of scope until:
- drag + shuffle + typed fallback are stable in testing
- gesture conflict behavior is defined (drag vs rotate)
- we confirm this added complexity improves engagement for target users
