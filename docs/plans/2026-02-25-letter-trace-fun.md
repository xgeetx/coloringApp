# Letter Trace Fun Implementation Plan

> **STATUS: SUPERSEDED — 2026-02-25**
> LetterTraceView.swift was moved to `Packages/TraceFun/Sources/TraceFun/LetterTraceView.swift`.
> The file is a **local Swift package** (`public struct LetterTraceView`), NOT a file in `ColoringApp/`.
> The UUID reference section below is obsolete — those UUIDs were removed from `project.pbxproj`.
> See CLAUDE.md → "Swift Package Protocol" for how to add future apps.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Build a voice-driven letter-tracing app for the 4th hub tile — say a word, letters pop out of a keyboard one by one in a slow staggered animation, then the child traces each letter with their finger using rainbow paint, hearing each letter name when complete.

**Architecture:** Single `LetterTraceView.swift`. State machine: `.idle → .listening → .confirm(word) → .tracing(word, letterIndex) → .celebrate(word)`. Screen 1 (idle/listening) is mic-only — no keyboard. After "Trace It!" is tapped, keyboard slides up and each word letter pops out from its row with a staggered spring animation, landing as a small tile. The active letter is shown large in the centre for tracing; a Canvas masked to the letter's text shape fills with rainbow paint as the kid drags. Completion uses cumulative drag distance (≥ 350 px). App is registered as app4, replacing the Story Time placeholder.

**Tech Stack:** SwiftUI, SFSpeechRecognizer (iOS 15+), AVSpeechSynthesizer, Canvas (iOS 15+), DragGesture, spring animations. No new dependencies.

---

## UUID Reference (copy-paste into pbxproj)

```
PBXBuildFile   : A8B8C9D0E1F2A3B4C5D6E7F8
PBXFileRef     : B9C9D0E1F2A3B4C5D6E7F8A9
```

---

### Task 1: Create `LetterTraceView.swift`

**Files:**
- Create: `ColoringApp/LetterTraceView.swift`

**Step 1: Create the file with full implementation**

```swift
import SwiftUI
import Speech
import AVFoundation

// MARK: - Root

struct LetterTraceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LetterTraceViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(r: 220, g: 245, b: 255),
                    Color(r: 255, g: 225, b: 245),
                    Color(r: 255, g: 248, b: 210),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TraceTopBar(vm: vm, onHome: { dismiss() })
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                GeometryReader { geo in
                    switch vm.phase {
                    case .idle, .listening:
                        TraceMicView(vm: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .confirm(let word):
                        TraceConfirmView(vm: vm, word: word)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .tracing(let word, let idx):
                        TraceStageView(vm: vm, word: word, containerSize: geo.size, currentIndex: idx)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .celebrate(let word):
                        TraceCelebView(vm: vm, word: word)
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
final class LetterTraceViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case confirm(String)
        case tracing(String, Int)   // word, current letter index
        case celebrate(String)
    }

    struct TraceTile: Identifiable {
        let id = UUID()
        let letter: String
        let colorIndex: Int
        var hasPopped: Bool = false
        var isComplete: Bool = false
        var paintPoints: [CGPoint] = []
        var totalDragDistance: CGFloat = 0
    }

    @Published var phase: Phase = .idle
    @Published var transcript: String = ""
    @Published var permissionDenied = false
    @Published var tiles: [TraceTile] = []

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    let synthesizer = AVSpeechSynthesizer()

    let tileColors: [Color] = [
        Color(r: 255, g: 100, b: 120),
        Color(r: 255, g: 155, b: 50),
        Color(r: 70,  g: 180, b: 100),
        Color(r: 60,  g: 135, b: 235),
        Color(r: 155, g: 80,  b: 220),
        Color(r: 235, g: 80,  b: 175),
    ]

    func tileColor(at index: Int) -> Color { tileColors[index % tileColors.count] }

    // MARK: - Tiles

    func buildTiles(for word: String) {
        tiles = word.enumerated().map { i, ch in
            TraceTile(letter: String(ch), colorIndex: i)
        }
    }

    func popTiles() {
        // Guard against double-pop if onAppear fires more than once
        guard tiles.allSatisfy({ !$0.hasPopped }) else { return }
        for i in tiles.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                    self.tiles[i].hasPopped = true
                }
            }
        }
    }

    func addPaintPoint(_ pt: CGPoint, tileIndex: Int, prevPt: CGPoint?) {
        guard tileIndex < tiles.count else { return }
        tiles[tileIndex].paintPoints.append(pt)
        if let prev = prevPt {
            let dx = pt.x - prev.x
            let dy = pt.y - prev.y
            tiles[tileIndex].totalDragDistance += sqrt(dx * dx + dy * dy)
        }
    }

    func checkCompletion(tileIndex: Int) {
        guard tileIndex < tiles.count, !tiles[tileIndex].isComplete else { return }
        guard tiles[tileIndex].totalDragDistance >= 350 else { return }
        tiles[tileIndex].isComplete = true
        let letter = tiles[tileIndex].letter
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: letter)
        utterance.rate = 0.38
        utterance.pitchMultiplier = 1.3
        synthesizer.speak(utterance)
        let nextIndex = tileIndex + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if nextIndex < self.tiles.count {
                let word = self.tiles.map { $0.letter }.joined()
                self.phase = .tracing(word, nextIndex)
            } else {
                let word = self.tiles.map { $0.letter }.joined()
                self.phase = .celebrate(word)
                self.speakCelebration(word: word)
            }
        }
    }

    func speakCelebration(word: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.synthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: "You spelled \(word)! Great job!")
            utterance.rate = 0.42
            utterance.pitchMultiplier = 1.2
            self.synthesizer.speak(utterance)
        }
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

    // MARK: - Speech recording

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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buf, _ in
            request?.append(buf)
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
        tiles = []
        phase = .idle
    }
}

// MARK: - Top Bar

struct TraceTopBar: View {
    @ObservedObject var vm: LetterTraceViewModel
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TraceBarButton(icon: "house.fill", label: "Home", color: .indigo) { onHome() }
            Spacer()
            Text(titleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            if case .tracing = vm.phase {
                TraceBarButton(icon: "arrow.counterclockwise", label: "New Word", color: .orange) { vm.reset() }
            } else {
                Color.clear.frame(width: 72, height: 52)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.1), radius: 4))
    }

    private var titleText: String {
        switch vm.phase {
        case .idle:                 return "🖍️ Trace Fun!"
        case .listening:            return "🎤 Listening…"
        case .confirm(let word):    return "📝 \(word)?"
        case .tracing(let word, _): return word
        case .celebrate:            return "🎉 Amazing!"
        }
    }
}

struct TraceBarButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: {
            action()
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
        }) {
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

// MARK: - Mic View (Screen 1 — word capture only, no keyboard)

struct TraceMicView: View {
    @ObservedObject var vm: LetterTraceViewModel
    @State private var pulse = false

    private var isListening: Bool {
        if case .listening = vm.phase { return true }
        return false
    }

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
                        .fill(isListening ? Color.red : Color(r: 120, g: 60, b: 220))
                        .frame(width: 160, height: 160)
                        .shadow(color: (isListening ? Color.red : Color(r: 120, g: 60, b: 220)).opacity(0.4),
                                radius: pulse ? 40 : 20)
                        .scaleEffect(pulse ? 1.06 : 1.0)
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 70)).foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = isListening
                }
            }
            .onChange(of: isListening) { _ in
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = isListening
                }
            }

            Group {
                if isListening && !vm.transcript.isEmpty {
                    Text(vm.transcript)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                } else {
                    Text(isListening ? "Tap to stop" : "Say a word!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(r: 120, g: 60, b: 220))
                }
            }
            .animation(.default, value: vm.transcript)

            if vm.permissionDenied {
                Label("Microphone access needed — check Settings", systemImage: "mic.slash")
                    .font(.subheadline).foregroundStyle(.red)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

// MARK: - Confirm View (Screen 2 — no keyboard)

struct TraceConfirmView: View {
    @ObservedObject var vm: LetterTraceViewModel
    let word: String

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("Did you say…")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(word)
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(Color(r: 120, g: 60, b: 220))
            HStack(spacing: 24) {
                Button(action: { vm.reset() }) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.7)))
                }
                .buttonStyle(.plain)
                Button(action: {
                    vm.buildTiles(for: word)
                    vm.phase = .tracing(word, 0)
                }) {
                    Label("Trace It! ✨", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36).padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(r: 120, g: 60, b: 220))
                                .shadow(color: Color(r: 120, g: 60, b: 220).opacity(0.4), radius: 8, y: 4)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Tracing Stage (Screen 3 — keyboard + letter pop + tracing)

struct TraceStageView: View {
    @ObservedObject var vm: LetterTraceViewModel
    let word: String
    let containerSize: CGSize
    let currentIndex: Int

    private var keyboardHeight: CGFloat { containerSize.height * 0.35 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 10) {
                ForEach(vm.tiles.indices, id: \.self) { i in
                    Circle()
                        .fill(vm.tiles[i].isComplete
                              ? vm.tileColor(at: i)
                              : Color.gray.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(i == currentIndex ? 1.35 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentIndex)
                }
            }
            .padding(.vertical, 8)

            // Tile row — letters that have popped out of the keyboard
            HStack(spacing: 12) {
                ForEach(Array(vm.tiles.enumerated()), id: \.element.id) { i, tile in
                    if tile.hasPopped {
                        SmallTileView(
                            letter: tile.letter,
                            color: vm.tileColor(at: i),
                            isActive: i == currentIndex,
                            isDone: tile.isComplete
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.2).combined(with: .opacity)),
                            removal: .identity
                        ))
                    } else {
                        // Placeholder holds layout while tile is still in keyboard
                        Color.clear.frame(width: 52, height: 52)
                    }
                }
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.6),
                       value: vm.tiles.filter { $0.hasPopped }.count)
            .padding(.vertical, 6)

            // Big tracing letter in centre
            if currentIndex < vm.tiles.count {
                TracingLetterView(vm: vm, tileIndex: currentIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Keyboard panel at bottom — appears here; letters pop out via tile-row animation above
            TraceKeyboardPanel(word: word)
                .frame(height: keyboardHeight)
        }
        .onAppear {
            vm.popTiles()
        }
    }
}

// MARK: - Small Tile View

struct SmallTileView: View {
    let letter: String
    let color: Color
    let isActive: Bool
    let isDone: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isDone ? color : (isActive ? color : color.opacity(0.4)))
                .frame(width: 52, height: 52)
                .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 8)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
            } else {
                Text(letter)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isActive ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
}

// MARK: - Tracing Letter View

// Rainbow paint fills inside the letter as kid drags.
// Canvas + .mask(Text) clips paint to the exact letter glyph shape.
// Completion: cumulative drag distance >= 350 px.

struct TracingLetterView: View {
    @ObservedObject var vm: LetterTraceViewModel
    let tileIndex: Int
    @State private var lastPoint: CGPoint? = nil

    private var tile: LetterTraceViewModel.TraceTile? {
        guard tileIndex < vm.tiles.count else { return nil }
        return vm.tiles[tileIndex]
    }

    var body: some View {
        GeometryReader { _ in
            let letter = tile?.letter ?? ""
            let paintPoints = tile?.paintPoints ?? []
            let progress = min(1.0, (tile?.totalDragDistance ?? 0) / 350.0)

            ZStack {
                // Faint guide letter
                Text(letter)
                    .font(.system(size: 240, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Rainbow paint clipped to the letter's glyph
                Canvas { ctx, size in
                    for pt in paintPoints {
                        let radius: CGFloat = 28
                        let hue = (pt.x + pt.y) / (size.width + size.height)
                        let color = Color(hue: Double(hue).truncatingRemainder(dividingBy: 1.0),
                                         saturation: 0.9, brightness: 1.0)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: pt.x - radius, y: pt.y - radius,
                                                   width: radius * 2, height: radius * 2)),
                            with: .color(color)
                        )
                    }
                }
                .mask(
                    Text(letter)
                        .font(.system(size: 240, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Circular progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .pink, .orange, .yellow, .green, .blue, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 260, height: 260)
                    .opacity(0.6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let pt = value.location
                        vm.addPaintPoint(pt, tileIndex: tileIndex, prevPt: lastPoint)
                        lastPoint = pt
                        vm.checkCompletion(tileIndex: tileIndex)
                    }
                    .onEnded { _ in lastPoint = nil }
            )
        }
    }
}

// MARK: - Keyboard Panel (read-only, bottom of screen)
//
// All 26 letters in 3 rows. Word's letters highlighted in purple.
// Not interactive — visual only, shows the origin of each popped tile.

struct TraceKeyboardPanel: View {
    let word: String

    private let rows: [[String]] = [
        ["A","B","C","D","E","F","G","H","I"],
        ["J","K","L","M","N","O","P","Q","R"],
        ["S","T","U","V","W","X","Y","Z"],
    ]

    private var wordLetters: Set<String> { Set(word.map { String($0) }) }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 4) {
                    ForEach(rows[rowIdx], id: \.self) { letter in
                        let inWord = wordLetters.contains(letter)
                        Text(letter)
                            .font(.system(size: 20, weight: inWord ? .black : .regular, design: .rounded))
                            .foregroundStyle(inWord ? Color.white : Color.secondary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(inWord
                                          ? Color(r: 120, g: 60, b: 220)
                                          : Color.white.opacity(0.55))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Celebrate View

struct TraceCelebView: View {
    @ObservedObject var vm: LetterTraceViewModel
    let word: String
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            Text("🎉")
                .font(.system(size: 100))
                .scaleEffect(bounce ? 1.2 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.4).repeatForever(autoreverses: true),
                           value: bounce)
                .onAppear { bounce = true }

            // Completed word in coloured tiles
            HStack(spacing: 8) {
                ForEach(Array(vm.tiles.enumerated()), id: \.element.id) { i, tile in
                    Text(tile.letter)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(vm.tileColor(at: i))
                                .shadow(color: vm.tileColor(at: i).opacity(0.5), radius: 8, y: 4)
                        )
                }
            }

            Text("Amazing!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color(r: 120, g: 60, b: 220))

            Button(action: { vm.reset() }) {
                Label("New Word", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(r: 120, g: 60, b: 220))
                            .shadow(color: Color(r: 120, g: 60, b: 220).opacity(0.4), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

#Preview {
    LetterTraceView()
}
```

**Step 2: Verify the file was created**

```bash
ls -la ColoringApp/LetterTraceView.swift
```
Expected: file exists, ~8–10 KB.

**Step 3: Commit**

```bash
git add ColoringApp/LetterTraceView.swift
git commit -m "feat: add LetterTraceView — voice-to-trace with keyboard letter pop animation"
```

---

### Task 2: Register `LetterTraceView.swift` in `project.pbxproj`

All 4 insertions required — missing any one causes "cannot find LetterTraceView in scope" build error.

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj`

**Step 1: Add PBXBuildFile entry**

After the line containing `E6F6A7B8C9D0E1F2A3B4C5D6 /* SpellingView.swift in Sources */`, insert:
```
		A8B8C9D0E1F2A3B4C5D6E7F8 /* LetterTraceView.swift in Sources */ = {isa = PBXBuildFile; fileRef = B9C9D0E1F2A3B4C5D6E7F8A9 /* LetterTraceView.swift */; };
```

**Step 2: Add PBXFileReference entry**

After the line containing `F7A7B8C9D0E1F2A3B4C5D6E7 /* SpellingView.swift */` (in the PBXFileReference section), insert:
```
		B9C9D0E1F2A3B4C5D6E7F8A9 /* LetterTraceView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LetterTraceView.swift; sourceTree = "<group>"; };
```

**Step 3: Add to PBXGroup children**

After the line containing `F7A7B8C9D0E1F2A3B4C5D6E7 /* SpellingView.swift */,` (in the PBXGroup children list), insert:
```
				B9C9D0E1F2A3B4C5D6E7F8A9 /* LetterTraceView.swift */,
```

**Step 4: Add to PBXSourcesBuildPhase**

After the line containing `E6F6A7B8C9D0E1F2A3B4C5D6 /* SpellingView.swift in Sources */,`, insert:
```
				A8B8C9D0E1F2A3B4C5D6E7F8 /* LetterTraceView.swift in Sources */,
```

**Step 5: Verify all 4 references present**

```bash
grep "LetterTraceView" ColoringFun.xcodeproj/project.pbxproj
```
Expected: exactly 4 lines.

**Step 6: Commit**

```bash
git add ColoringFun.xcodeproj/project.pbxproj
git commit -m "feat: register LetterTraceView.swift in pbxproj (all 4 sections)"
```

---

### Task 3: Activate app4 in `AppRegistry.swift`

**Files:**
- Modify: `ColoringApp/AppRegistry.swift`

**Step 1: Replace the app4 placeholder**

Find:
```swift
        .placeholder(id: "app4", icon: "📖", displayName: "Story Time"),
```

Replace with:
```swift
        MiniAppDescriptor(
            id: "tracefun",
            displayName: "Trace Fun",
            subtitle: "Trace a Word!",
            icon: "🖍️",
            tileColor: Color(r: 180, g: 255, b: 220),
            isAvailable: true,
            makeRootView: { AnyView(LetterTraceView()) }
        ),
```

**Step 2: Verify `apps` array still closes with `]` and all commas are correct.**

**Step 3: Commit**

```bash
git add ColoringApp/AppRegistry.swift
git commit -m "feat: activate Trace Fun as 4th hub tile"
```

---

### Task 4: Build on simulator and verify

**Step 1: Push all commits**

```bash
git push
```

**Step 2: Build on Mac**

```bash
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 | grep -E '(error:|BUILD)'"
```

Expected: `BUILD SUCCEEDED`, zero `error:` lines.

If errors appear: read the full build log without the grep filter to find the culprit line.

---

## Testing Checklist

- [ ] Hub shows 🖍️ Trace Fun tile (mint green, "Trace a Word!")
- [ ] Tap tile → LetterTraceView opens full screen — **mic screen only, no keyboard**
- [ ] Big purple mic button, "Say a word!" label
- [ ] Tap mic → pulses red, transcribes speech
- [ ] Say "cat" → confirm screen shows CAT — **still no keyboard**
- [ ] "Try Again" → back to mic
- [ ] "Trace It! ✨" → tracing stage: keyboard slides in at bottom
- [ ] Word letters (C, A, T) highlighted purple on keyboard
- [ ] 3 letter tiles pop out of keyboard one by one (~0.4s stagger), land above
- [ ] First tile (C) is active (larger, full colour); others are dimmer
- [ ] Progress dots at top: 3 dots, first lit
- [ ] Large faint C in centre, circular progress ring around it
- [ ] Drag finger over C → rainbow paint fills inside the letter only
- [ ] Paint appears inside the letter glyph, not outside
- [ ] Ring progress fills as finger drags (~350px to complete)
- [ ] On completion: TTS says "C", tile gets checkmark, A becomes active
- [ ] Repeat for A, T
- [ ] After T → celebrate screen: 🎉, CAT in rainbow tiles, "Amazing!", TTS
- [ ] "New Word" → back to mic screen (clean state, no keyboard)
- [ ] Home button → back to Hub
