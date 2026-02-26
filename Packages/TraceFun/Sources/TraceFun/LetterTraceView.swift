import SwiftUI
import UIKit
import Speech
import AVFoundation
import CoreText

// MARK: - Glyph Path Helper

struct LetterGlyphPath {
    let path: Path
    let boundingRect: CGRect
    let outlinePoints: [CGPoint]

    static func extract(letter: String, fontSize: CGFloat) -> LetterGlyphPath? {
        let uiFont = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let ctFont = uiFont as CTFont
        guard let firstChar = letter.unicodeScalars.first else { return nil }
        let chars = [UniChar(firstChar.value)]
        var glyphs = [CGGlyph](repeating: 0, count: 1)
        CTFontGetGlyphsForCharacters(ctFont, chars, &glyphs, 1)
        let glyph = glyphs[0]
        guard glyph != 0 else { return nil }
        guard let cgPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { return nil }

        // Core Text glyphs have origin at baseline-left with Y up.
        // Flip Y so it matches SwiftUI coordinate space (Y down).
        let box = cgPath.boundingBox
        var flipTransform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -box.maxY - box.minY)
        let flippedCG = cgPath.copy(using: &flipTransform) ?? cgPath
        let swiftPath = Path(flippedCG)
        let bounds = swiftPath.boundingRect
        let sampled = Self.samplePathPoints(cgPath: flippedCG, spacing: 20)
        return LetterGlyphPath(path: swiftPath, boundingRect: bounds, outlinePoints: sampled)
    }

    // MARK: - Path Sampling

    /// Walk all path elements and sample points at regular intervals along the outline.
    static func samplePathPoints(cgPath: CGPath, spacing: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var residual: CGFloat = 0  // distance left over from last segment

        cgPath.applyWithBlock { elementPtr in
            let el = elementPtr.pointee
            switch el.type {
            case .moveToPoint:
                currentPoint = el.points[0]
                residual = 0
            case .addLineToPoint:
                let end = el.points[0]
                sampleLine(from: currentPoint, to: end, spacing: spacing,
                           residual: &residual, into: &points)
                currentPoint = end
            case .addQuadCurveToPoint:
                let cp = el.points[0], end = el.points[1]
                sampleQuadCurve(from: currentPoint, cp: cp, to: end,
                                spacing: spacing, residual: &residual, into: &points)
                currentPoint = end
            case .addCurveToPoint:
                let cp1 = el.points[0], cp2 = el.points[1], end = el.points[2]
                sampleCubicCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: end,
                                 spacing: spacing, residual: &residual, into: &points)
                currentPoint = end
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return points
    }

    private static func sampleLine(from p0: CGPoint, to p1: CGPoint, spacing: CGFloat,
                                    residual: inout CGFloat, into points: inout [CGPoint]) {
        let dx = p1.x - p0.x, dy = p1.y - p0.y
        let segLen = sqrt(dx * dx + dy * dy)
        guard segLen > 0.001 else { return }
        var traveled = residual > 0 ? spacing - residual : 0
        while traveled <= segLen {
            let t = traveled / segLen
            points.append(CGPoint(x: p0.x + dx * t, y: p0.y + dy * t))
            traveled += spacing
        }
        residual = segLen - (traveled - spacing)
    }

    private static func sampleQuadCurve(from p0: CGPoint, cp: CGPoint, to p2: CGPoint,
                                         spacing: CGFloat, residual: inout CGFloat,
                                         into points: inout [CGPoint]) {
        // Flatten to small line segments then sample
        let steps = max(8, Int(quadApproxLength(p0: p0, cp: cp, p2: p2) / 4))
        var prev = p0
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p2.x
            let y = mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p2.y
            let next = CGPoint(x: x, y: y)
            sampleLine(from: prev, to: next, spacing: spacing, residual: &residual, into: &points)
            prev = next
        }
    }

    private static func sampleCubicCurve(from p0: CGPoint, cp1: CGPoint, cp2: CGPoint,
                                          to p3: CGPoint, spacing: CGFloat,
                                          residual: inout CGFloat, into points: inout [CGPoint]) {
        let steps = max(12, Int(cubicApproxLength(p0: p0, cp1: cp1, cp2: cp2, p3: p3) / 4))
        var prev = p0
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt*mt*mt*p0.x + 3*mt*mt*t*cp1.x + 3*mt*t*t*cp2.x + t*t*t*p3.x
            let y = mt*mt*mt*p0.y + 3*mt*mt*t*cp1.y + 3*mt*t*t*cp2.y + t*t*t*p3.y
            let next = CGPoint(x: x, y: y)
            sampleLine(from: prev, to: next, spacing: spacing, residual: &residual, into: &points)
            prev = next
        }
    }

    private static func quadApproxLength(p0: CGPoint, cp: CGPoint, p2: CGPoint) -> CGFloat {
        let d1 = hypot(cp.x - p0.x, cp.y - p0.y)
        let d2 = hypot(p2.x - cp.x, p2.y - cp.y)
        return d1 + d2
    }

    private static func cubicApproxLength(p0: CGPoint, cp1: CGPoint, cp2: CGPoint, p3: CGPoint) -> CGFloat {
        let d1 = hypot(cp1.x - p0.x, cp1.y - p0.y)
        let d2 = hypot(cp2.x - cp1.x, cp2.y - cp1.y)
        let d3 = hypot(p3.x - cp2.x, p3.y - cp2.y)
        return d1 + d2 + d3
    }

    /// Returns the outline stroked to `width` as a filled path — useful for hit-testing proximity.
    func strokedBand(width: CGFloat) -> Path {
        let strokedCG = path.cgPath.copy(
            strokingWithWidth: width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        return Path(strokedCG)
    }

    /// Even-odd containment — required because Core Text glyph paths use even-odd winding
    /// for counters (e.g. the hole in P, B, D, O, etc.).
    func eoContains(point: CGPoint) -> Bool {
        path.cgPath.contains(point, using: .evenOdd)
    }

    func isNearOutline(point: CGPoint, bandWidth: CGFloat) -> Bool {
        let band = strokedBand(width: bandWidth)
        return band.contains(point)
    }
}

// MARK: - Difficulty

enum TraceDifficulty: String, CaseIterable {
    case easy, medium, tricky

    var outlineBandWidth: CGFloat {
        switch self {
        case .easy:   return 0    // full fill — any drag inside counts
        case .medium: return 50
        case .tricky: return 28
        }
    }

    var requiredCoverage: CGFloat {
        switch self {
        case .easy:   return 0.50
        case .medium: return 0.65
        case .tricky: return 0.80
        }
    }

    /// How close drag must be to "cover" a checkpoint, as fraction of fontSize.
    var checkpointRadiusFraction: CGFloat {
        switch self {
        case .easy:   return 0.12
        case .medium: return 0.08
        case .tricky: return 0.05
        }
    }

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .tricky: return "Tricky"
        }
    }

    var description: String {
        switch self {
        case .easy:   return "Color anywhere inside the letter"
        case .medium: return "Stay close to the letter edges"
        case .tricky: return "Trace right along the outline"
        }
    }

    var emoji: String {
        switch self {
        case .easy:   return "🌟"
        case .medium: return "✏️"
        case .tricky: return "🎯"
        }
    }

    static func load() -> TraceDifficulty {
        let raw = UserDefaults.standard.string(forKey: "traceFunDifficulty") ?? "easy"
        return TraceDifficulty(rawValue: raw) ?? .easy
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "traceFunDifficulty")
    }
}

// MARK: - Root

public struct LetterTraceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LetterTraceViewModel()

    public init() {}

    public var body: some View {
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
        var effectiveDragDistance: CGFloat = 0
        var coveredCheckpoints: Set<Int> = []
    }

    @Published var phase: Phase = .idle
    @Published var transcript: String = ""
    @Published var permissionDenied = false
    @Published var tiles: [TraceTile] = []
    @Published var difficulty: TraceDifficulty = .load()

    func setDifficulty(_ d: TraceDifficulty) {
        difficulty = d
        d.save()
    }

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

    func addPaintPoint(_ pt: CGPoint, tileIndex: Int, prevPt: CGPoint?,
                        glyphPath: LetterGlyphPath?, letterOrigin: CGPoint,
                        fontSize: CGFloat) {
        guard tileIndex < tiles.count else { return }
        tiles[tileIndex].paintPoints.append(pt)
        if let prev = prevPt {
            let dx = pt.x - prev.x
            let dy = pt.y - prev.y
            let dist = sqrt(dx * dx + dy * dy)
            tiles[tileIndex].totalDragDistance += dist

            // Compute effective distance based on difficulty
            if difficulty == .easy {
                // Easy: any drag inside the filled letter counts
                if let gp = glyphPath {
                    let localPt = CGPoint(x: pt.x - letterOrigin.x, y: pt.y - letterOrigin.y)
                    if gp.eoContains(point: localPt) {
                        tiles[tileIndex].effectiveDragDistance += dist
                    }
                } else {
                    tiles[tileIndex].effectiveDragDistance += dist
                }
            } else {
                // Medium/Tricky: must be near the outline
                if let gp = glyphPath {
                    let localPt = CGPoint(x: pt.x - letterOrigin.x, y: pt.y - letterOrigin.y)
                    if gp.isNearOutline(point: localPt, bandWidth: difficulty.outlineBandWidth) {
                        tiles[tileIndex].effectiveDragDistance += dist
                    }
                } else {
                    tiles[tileIndex].effectiveDragDistance += dist
                }
            }
        }

        // Coverage-based checkpoint tracking
        if let gp = glyphPath {
            let checkRadius = fontSize * difficulty.checkpointRadiusFraction
            let checkRadiusSq = checkRadius * checkRadius
            // Convert drag point to glyph-local coordinates
            let localPt = CGPoint(x: pt.x - letterOrigin.x, y: pt.y - letterOrigin.y)
            for (idx, outlinePt) in gp.outlinePoints.enumerated() {
                if tiles[tileIndex].coveredCheckpoints.contains(idx) { continue }
                let dx = localPt.x - outlinePt.x
                let dy = localPt.y - outlinePt.y
                if dx * dx + dy * dy <= checkRadiusSq {
                    tiles[tileIndex].coveredCheckpoints.insert(idx)
                }
            }
        }
    }

    func checkCompletion(tileIndex: Int, outlinePointCount: Int) {
        guard tileIndex < tiles.count, !tiles[tileIndex].isComplete else { return }
        guard outlinePointCount > 0 else { return }
        // Scale required coverage down for complex letters with long perimeters.
        // Reference ~30 points (simple letter like C or L). Letters with more points
        // get a reduced requirement via sqrt scaling so W/M aren't punishing.
        let referenceCount: CGFloat = 30
        let scale = min(1.0, sqrt(referenceCount / CGFloat(outlinePointCount)))
        let adjustedCoverage = difficulty.requiredCoverage * scale
        let coverage = CGFloat(tiles[tileIndex].coveredCheckpoints.count) / CGFloat(outlinePointCount)
        guard coverage >= adjustedCoverage else { return }
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
    @State private var showSettings = false
    @State private var tapTimestamps: [Date] = []

    var body: some View {
        HStack(spacing: 12) {
            TraceBarButton(icon: "house.fill", label: "Home", color: .indigo) { onHome() }
            Spacer()
            Text(titleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 8) {
                if case .tracing = vm.phase {
                    TraceBarButton(icon: "arrow.counterclockwise", label: "New Word", color: .orange) { vm.reset() }
                }
                // Gear icon — triple-tap gate
                Button(action: { handleGearTap() }) {
                    VStack(spacing: 3) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Settings")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.gray)
                    .frame(width: 72, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.1), radius: 4))
        .sheet(isPresented: $showSettings) {
            TraceDifficultySheet(vm: vm)
        }
    }

    private func handleGearTap() {
        let now = Date()
        tapTimestamps.append(now)
        // Keep only taps within the last 2 seconds
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2.0 }
        if tapTimestamps.count >= 3 {
            tapTimestamps = []
            showSettings = true
        }
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

// MARK: - Difficulty Settings Sheet

struct TraceDifficultySheet: View {
    @ObservedObject var vm: LetterTraceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Tracing Difficulty")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(r: 120, g: 60, b: 220))
                    .padding(.top, 16)

                ForEach(TraceDifficulty.allCases, id: \.rawValue) { level in
                    Button(action: {
                        vm.setDifficulty(level)
                    }) {
                        HStack(spacing: 16) {
                            Text(level.emoji)
                                .font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.label)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                Text(level.description)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if vm.difficulty == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color(r: 120, g: 60, b: 220))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(vm.difficulty == level
                                      ? Color(r: 120, g: 60, b: 220).opacity(0.12)
                                      : Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(vm.difficulty == level
                                        ? Color(r: 120, g: 60, b: 220).opacity(0.4)
                                        : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(r: 120, g: 60, b: 220))
                }
            }
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

    private var keyboardHeight: CGFloat { containerSize.height * 0.18 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
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
            .padding(.vertical, 4)

            // Tile row — letters that have popped out of the keyboard
            HStack(spacing: 10) {
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
            .padding(.vertical, 4)

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

// Hollow outline tracing: kid traces along the edges of a big letter.
// Difficulty controls how strictly they must follow the outline.
// Paint is masked to the valid tracing region (fill for easy, band for medium/tricky).

struct TracingLetterView: View {
    @ObservedObject var vm: LetterTraceViewModel
    let tileIndex: Int
    @State private var lastPoint: CGPoint? = nil
    @State private var glyphData: LetterGlyphPath? = nil
    @State private var letterOrigin: CGPoint = .zero

    private var tile: LetterTraceViewModel.TraceTile? {
        guard tileIndex < vm.tiles.count else { return nil }
        return vm.tiles[tileIndex]
    }

    var body: some View {
        GeometryReader { geo in
            let letter = tile?.letter ?? ""
            let paintPoints = tile?.paintPoints ?? []
            let fontSize = min(geo.size.width, geo.size.height) * 0.95
            let paintRadius = max(20, fontSize * 0.06)

            ZStack {
                // Extract glyph and compute centering
                Color.clear.onAppear {
                    extractGlyph(letter: letter, fontSize: fontSize, in: geo.size)
                }

                if let glyph = glyphData {
                    // Faint fill behind at easy difficulty
                    if vm.difficulty == .easy {
                        glyph.path
                            .offsetBy(dx: letterOrigin.x, dy: letterOrigin.y)
                            .fill(Color.gray.opacity(0.06), style: FillStyle(eoFill: true))
                    }

                    // Dashed outline guide
                    glyph.path
                        .offsetBy(dx: letterOrigin.x, dy: letterOrigin.y)
                        .stroke(
                            Color.gray.opacity(0.35),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 6])
                        )

                    // Rainbow paint masked to valid tracing region
                    Canvas { ctx, size in
                        for pt in paintPoints {
                            let hue = (pt.x + pt.y) / (size.width + size.height)
                            let color = Color(hue: Double(hue).truncatingRemainder(dividingBy: 1.0),
                                             saturation: 0.9, brightness: 1.0)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: pt.x - paintRadius, y: pt.y - paintRadius,
                                                       width: paintRadius * 2, height: paintRadius * 2)),
                                with: .color(color)
                            )
                        }
                    }
                    .mask(paintMask(glyph: glyph))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Checkpoint dots along the letter outline — light up as covered
                if let glyph = glyphData {
                    let covered = tile?.coveredCheckpoints ?? []
                    Canvas { ctx, _ in
                        let dotRadius: CGFloat = max(6, fontSize * 0.018)
                        for (idx, outlinePt) in glyph.outlinePoints.enumerated() {
                            let viewPt = CGPoint(x: outlinePt.x + letterOrigin.x,
                                                 y: outlinePt.y + letterOrigin.y)
                            let rect = CGRect(x: viewPt.x - dotRadius, y: viewPt.y - dotRadius,
                                              width: dotRadius * 2, height: dotRadius * 2)
                            if covered.contains(idx) {
                                let hue = Double(idx) / max(1, Double(glyph.outlinePoints.count))
                                let color = Color(hue: hue, saturation: 0.85, brightness: 1.0)
                                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                            } else {
                                ctx.fill(Path(ellipseIn: rect),
                                         with: .color(Color.gray.opacity(0.18)))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let pt = value.location
                        vm.addPaintPoint(pt, tileIndex: tileIndex, prevPt: lastPoint,
                                        glyphPath: glyphData, letterOrigin: letterOrigin,
                                        fontSize: fontSize)
                        lastPoint = pt
                        vm.checkCompletion(tileIndex: tileIndex,
                                          outlinePointCount: glyphData?.outlinePoints.count ?? 0)
                    }
                    .onEnded { _ in lastPoint = nil }
            )
            .onChange(of: tileIndex) { _ in
                let newLetter = (tileIndex < vm.tiles.count) ? vm.tiles[tileIndex].letter : ""
                extractGlyph(letter: newLetter, fontSize: fontSize, in: geo.size)
                lastPoint = nil
            }
        }
    }

    private func extractGlyph(letter: String, fontSize: CGFloat, in size: CGSize) {
        guard let glyph = LetterGlyphPath.extract(letter: letter, fontSize: fontSize) else {
            glyphData = nil
            return
        }
        glyphData = glyph
        // Center the glyph in the available space
        let bounds = glyph.boundingRect
        letterOrigin = CGPoint(
            x: (size.width - bounds.width) / 2 - bounds.minX,
            y: (size.height - bounds.height) / 2 - bounds.minY
        )
    }

    @ViewBuilder
    private func paintMask(glyph: LetterGlyphPath) -> some View {
        if vm.difficulty == .easy {
            // Full letter fill as mask (even-odd for correct counters in P, B, D, etc.)
            glyph.path
                .offsetBy(dx: letterOrigin.x, dy: letterOrigin.y)
                .fill(Color.white, style: FillStyle(eoFill: true))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Outline band as mask
            glyph.strokedBand(width: vm.difficulty.outlineBandWidth)
                .offsetBy(dx: letterOrigin.x, dy: letterOrigin.y)
                .fill(Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
