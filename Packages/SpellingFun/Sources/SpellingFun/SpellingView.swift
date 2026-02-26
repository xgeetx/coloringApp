import SwiftUI
import Speech
import AVFoundation
import UIKit

public struct SpellingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SpellingViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(r: 200, g: 240, b: 255),
                    Color(r: 255, g: 220, b: 240),
                    Color(r: 255, g: 245, b: 200)
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

@MainActor
final class SpellingViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case spelling(String)
    }

    struct StageTile: Identifiable {
        let id = UUID()
        let letter: String
        let colorIndex: Int
        var offset: CGSize
        var rotation: Angle
        var appeared: Bool
    }

    @Published var phase: Phase = .idle
    @Published var transcript: String = ""
    @Published var permissionDenied = false
    @Published var stagedTiles: [StageTile] = []
    @Published var manualWordInput: String = ""
    @Published var validationError: String?
    @Published var shuffleRequestToken = 0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let dragStartHaptics = UIImpactFeedbackGenerator(style: .light)
    private let dragEndHaptics = UIImpactFeedbackGenerator(style: .soft)

    let synthesizer = AVSpeechSynthesizer()
    let tileColors: [Color] = [
        Color(r: 255, g: 100, b: 120),
        Color(r: 255, g: 160, b: 60),
        Color(r: 80, g: 180, b: 100),
        Color(r: 60, g: 140, b: 230),
        Color(r: 160, g: 80, b: 220),
        Color(r: 230, g: 80, b: 180)
    ]

    init() {
        dragStartHaptics.prepare()
        dragEndHaptics.prepare()
    }

    func tileColor(at index: Int) -> Color {
        tileColors[index % tileColors.count]
    }

    func animateLettersIn(word: String, stageSize: CGSize) {
        stagedTiles = []
        let letters = word.map { String($0) }
        let targetOffsets = randomOffsets(count: letters.count, stageSize: stageSize)

        for (index, letter) in letters.enumerated() {
            let start = keyboardLaunchOffset(for: letter, stageSize: stageSize)
            let tile = StageTile(
                letter: letter,
                colorIndex: index % tileColors.count,
                offset: start,
                rotation: .degrees(0),
                appeared: false
            )
            stagedTiles.append(tile)

            let tileID = tile.id
            let target = targetOffsets[index]
            let delay = 0.18 + Double(index) * 0.24

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let idx = self.stagedTiles.firstIndex(where: { $0.id == tileID }) {
                    withAnimation(.spring(response: 1.15, dampingFraction: 0.82)) {
                        self.stagedTiles[idx].offset = target
                        self.stagedTiles[idx].appeared = true
                    }
                }
            }
        }
    }

    func shuffleTiles(stageSize: CGSize) {
        guard !stagedTiles.isEmpty else { return }
        let shuffledOffsets = randomOffsets(count: stagedTiles.count, stageSize: stageSize)
        for idx in stagedTiles.indices {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.80)) {
                stagedTiles[idx].offset = shuffledOffsets[idx]
            }
        }
    }

    func requestShuffle() {
        shuffleRequestToken += 1
    }

    private func randomOffsets(count: Int, stageSize: CGSize) -> [CGSize] {
        let tileRadius: CGFloat = 52
        let xRange = max(10, stageSize.width / 2 - tileRadius)
        let yRange = max(10, stageSize.height / 2 - tileRadius)

        return (0..<count).map { _ in
            CGSize(
                width: CGFloat.random(in: -xRange...xRange),
                height: CGFloat.random(in: -yRange...yRange)
            )
        }
    }

    private func keyboardLaunchOffset(for letter: String, stageSize: CGSize) -> CGSize {
        let rows: [[String]] = [
            ["A", "B", "C", "D", "E", "F", "G", "H", "I"],
            ["J", "K", "L", "M", "N", "O", "P", "Q", "R"],
            ["S", "T", "U", "V", "W", "X", "Y", "Z"]
        ]

        let normalized = letter.uppercased()
        guard
            let rowIndex = rows.firstIndex(where: { $0.contains(normalized) }),
            let colIndex = rows[rowIndex].firstIndex(of: normalized)
        else {
            return CGSize(width: 0, height: stageSize.height * 0.72)
        }

        let row = rows[rowIndex]
        let progress = row.count == 1 ? 0.5 : CGFloat(colIndex) / CGFloat(row.count - 1)
        let x = (progress - 0.5) * stageSize.width * 0.86
        let y = stageSize.height * (0.62 + CGFloat(rowIndex) * 0.055)
        return CGSize(width: x, height: y)
    }

    func updateTileOffset(id: UUID, newOffset: CGSize, stageSize: CGSize) {
        guard let idx = stagedTiles.firstIndex(where: { $0.id == id }) else { return }
        stagedTiles[idx].offset = clampOffset(newOffset, stageSize: stageSize)
    }

    func updateTileRotation(id: UUID, newRotation: Angle) {
        guard let idx = stagedTiles.firstIndex(where: { $0.id == id }) else { return }
        stagedTiles[idx].rotation = newRotation
    }

    private func clampOffset(_ offset: CGSize, stageSize: CGSize) -> CGSize {
        let tileRadius: CGFloat = 52
        let maxX = max(10, stageSize.width / 2 - tileRadius)
        let maxY = max(10, stageSize.height / 2 - tileRadius)

        return CGSize(
            width: offset.width.clamped(to: -maxX...maxX),
            height: offset.height.clamped(to: -maxY...maxY)
        )
    }

    func speakLetter(_ letter: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: letter)
        utterance.rate = 0.40
        utterance.pitchMultiplier = 1.28
        synthesizer.speak(utterance)
    }

    func emitDragStartHaptic() {
        dragStartHaptics.impactOccurred()
        dragStartHaptics.prepare()
    }

    func emitDragEndHaptic() {
        dragEndHaptics.impactOccurred()
        dragEndHaptics.prepare()
    }

    func extractWord(from transcript: String) -> String? {
        let lower = transcript.lowercased()
        for marker in ["spell ", "spelling ", "how do you spell "] {
            if let range = lower.range(of: marker) {
                let rest = String(lower[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let first = rest.components(separatedBy: .whitespaces).first ?? ""
                if let normalized = normalizeWord(first) {
                    return normalized
                }
            }
        }

        let fillers: Set<String> = [
            "a", "the", "an", "i", "um", "uh", "and", "or", "so", "like", "it", "is", "was", "to", "do", "how", "what", "can", "you"
        ]

        let words = lower
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 && !fillers.contains($0) }

        if let last = words.last {
            return normalizeWord(last)
        }
        return nil
    }

    func normalizeWord(_ raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count >= 2, cleaned.count <= 20 else { return nil }
        guard cleaned.allSatisfy({ $0.isLetter }) else { return nil }
        return cleaned
    }

    func requestAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized else {
                    self.permissionDenied = true
                    return
                }

                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if granted { self.startRecording() }
                        else { self.permissionDenied = true }
                    }
                }
            }
        }
    }

    func startRecording() {
        validationError = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

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
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                    self.startSpellingFromTranscript()
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
            phase = .listening
        } catch {
            stopRecording()
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func startSpellingFromTranscript() {
        if let normalized = extractWord(from: transcript) {
            validationError = nil
            manualWordInput = normalized
            phase = .spelling(normalized)
        } else {
            validationError = "I could not hear a clear word. Type one below."
            phase = .idle
        }
    }

    func applyManualWord() {
        if let normalized = normalizeWord(manualWordInput) {
            validationError = nil
            manualWordInput = normalized
            phase = .spelling(normalized)
            return
        }
        validationError = "Use 2-20 letters (A-Z only)."
    }

    func reset() {
        stopRecording()
        transcript = ""
        manualWordInput = ""
        validationError = nil
        stagedTiles = []
        phase = .idle
    }
}

struct SpellingTopBar: View {
    @ObservedObject var vm: SpellingViewModel
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SpellingBarButton(icon: "house.fill", label: "Home", color: .indigo, action: onHome)
                .accessibilityLabel("Go Home")
                .accessibilityHint("Return to the app hub")

            Spacer()

            Text(titleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            if case .spelling = vm.phase {
                HStack(spacing: 8) {
                    SpellingBarButton(icon: "shuffle", label: "Shuffle", color: .purple) {
                        vm.requestShuffle()
                    }
                    .accessibilityLabel("Shuffle Letters")
                    .accessibilityHint("Move letters to new random positions")

                    SpellingBarButton(icon: "arrow.counterclockwise", label: "New", color: .orange) {
                        vm.reset()
                    }
                    .accessibilityLabel("New Word")
                    .accessibilityHint("Clear stage and return to microphone")
                }
            } else {
                Color.clear.frame(width: 160, height: 56)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.86))
                .shadow(color: .black.opacity(0.08), radius: 4)
        )
    }

    private var titleText: String {
        switch vm.phase {
        case .idle:
            return "Spelling Fun"
        case .listening:
            return "Listening"
        case .spelling(let word):
            return word
        }
    }
}

struct SpellingBarButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            action()
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            .frame(width: 72, height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.60), value: pressed)
    }
}

struct MicPromptView: View {
    @ObservedObject var vm: SpellingViewModel
    @State private var pulse = false

    private var isListening: Bool {
        if case .listening = vm.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Button(action: {
                if isListening {
                    vm.stopRecording()
                    vm.startSpellingFromTranscript()
                } else {
                    vm.requestAndStart()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red : Color.purple)
                        .frame(width: 164, height: 164)
                        .shadow(color: (isListening ? Color.red : Color.purple).opacity(0.30), radius: pulse ? 24 : 12)
                        .scaleEffect(pulse ? 1.04 : 1.0)

                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isListening ? "Stop Listening" : "Start Listening")
            .accessibilityHint("Speak a word and then stop recording")
            .onAppear { updatePulseState() }
            .onChange(of: isListening) { _ in updatePulseState() }

            Text(isListening ? "Tap to stop" : "Say a word")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.purple)
                .minimumScaleFactor(0.8)

            if isListening && !vm.transcript.isEmpty {
                Text(vm.transcript)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            if vm.permissionDenied {
                Label("Microphone access is needed. Check Settings.", systemImage: "mic.slash")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            Spacer()
        }
    }

    private func updatePulseState() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = isListening
        }
    }
}

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
        .onAppear { vm.animateLettersIn(word: word, stageSize: stageSize) }
        .onChange(of: word) { newWord in
            vm.animateLettersIn(word: newWord, stageSize: stageSize)
        }
        .onChange(of: vm.shuffleRequestToken) { _ in
            vm.shuffleTiles(stageSize: stageSize)
        }
    }
}

struct LetterStageView: View {
    @ObservedObject var vm: SpellingViewModel
    let stageSize: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.22))
                .padding(8)

            ForEach(vm.stagedTiles) { tile in
                DraggableTileView(vm: vm, tile: tile, stageSize: stageSize)
            }
        }
        .clipped()
    }
}

struct DraggableTileView: View {
    @ObservedObject var vm: SpellingViewModel
    let tile: SpellingViewModel.StageTile
    let stageSize: CGSize

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var rotationDelta: Angle = .degrees(0)
    @State private var hasSpokeThisDrag = false
    @State private var isDragging = false

    private let tileSize: CGFloat = 96

    var body: some View {
        Text(tile.letter)
            .font(.system(size: 68, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .frame(width: tileSize, height: tileSize)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(vm.tileColor(at: tile.colorIndex))
                    .shadow(
                        color: vm.tileColor(at: tile.colorIndex).opacity(isDragging ? 0.55 : 0.32),
                        radius: isDragging ? 10 : 4,
                        x: 0,
                        y: isDragging ? 4 : 2
                    )
            )
            .scaleEffect(isDragging ? 1.10 : (tile.appeared ? 1.0 : 0.05))
            .opacity(tile.appeared ? 1.0 : 0.0)
            .rotationEffect(tile.rotation + rotationDelta)
            .offset(
                x: tile.offset.width + dragDelta.width,
                y: tile.offset.height + dragDelta.height
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isDragging)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Letter \(tile.letter)")
            .accessibilityHint("Drag to move and hear the letter. Use two fingers to rotate.")
            .gesture(dragGesture)
            .simultaneousGesture(rotationGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !hasSpokeThisDrag {
                    hasSpokeThisDrag = true
                    isDragging = true
                    vm.emitDragStartHaptic()
                    vm.speakLetter(tile.letter)
                }
            }
            .onEnded { value in
                hasSpokeThisDrag = false
                isDragging = false
                vm.emitDragEndHaptic()
                vm.updateTileOffset(
                    id: tile.id,
                    newOffset: CGSize(
                        width: tile.offset.width + value.translation.width,
                        height: tile.offset.height + value.translation.height
                    ),
                    stageSize: stageSize
                )
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($rotationDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                vm.updateTileRotation(id: tile.id, newRotation: tile.rotation + value)
            }
    }
}

struct KeyboardDisplayPanel: View {
    let word: String

    private let rows: [[String]] = [
        ["A", "B", "C", "D", "E", "F", "G", "H", "I"],
        ["J", "K", "L", "M", "N", "O", "P", "Q", "R"],
        ["S", "T", "U", "V", "W", "X", "Y", "Z"]
    ]

    private var wordLetters: Set<String> {
        Set(word.map { String($0) })
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 5) {
                    ForEach(rows[rowIdx], id: \.self) { letter in
                        let inWord = wordLetters.contains(letter)
                        Text(letter)
                            .font(.system(size: 22, weight: inWord ? .black : .regular, design: .rounded))
                            .foregroundColor(inWord ? .purple : Color.secondary.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(inWord ? Color.purple.opacity(0.14) : Color.white.opacity(0.55))
                            )
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.86))
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: -1)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard preview")
        .accessibilityHint("Letters in the current word are highlighted")
    }
}

#Preview {
    SpellingView()
}

// MARK: - Private Extensions (inlined from main target's Models.swift)

private extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
