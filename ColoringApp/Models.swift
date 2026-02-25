import SwiftUI

// MARK: - Flyout Panel

enum FlyoutPanel: Equatable {
    case brushes, size, opacity, stamps
}

// MARK: - Crayola 16 Colors

struct CrayolaColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color

    static let palette: [CrayolaColor] = [
        CrayolaColor(name: "Red",          color: Color(r: 238, g: 32,  b: 77)),
        CrayolaColor(name: "Red-Orange",   color: Color(r: 255, g: 83,  b: 73)),
        CrayolaColor(name: "Orange",       color: Color(r: 255, g: 117, b: 56)),
        CrayolaColor(name: "Yellow-Orange",color: Color(r: 255, g: 174, b: 66)),
        CrayolaColor(name: "Yellow",       color: Color(r: 252, g: 232, b: 131)),
        CrayolaColor(name: "Yellow-Green", color: Color(r: 197, g: 227, b: 132)),
        CrayolaColor(name: "Green",        color: Color(r: 28,  g: 172, b: 120)),
        CrayolaColor(name: "Blue-Green",   color: Color(r: 25,  g: 158, b: 189)),
        CrayolaColor(name: "Blue",         color: Color(r: 31,  g: 117, b: 254)),
        CrayolaColor(name: "Blue-Violet",  color: Color(r: 115, g: 102, b: 189)),
        CrayolaColor(name: "Violet",       color: Color(r: 146, g: 110, b: 174)),
        CrayolaColor(name: "Red-Violet",   color: Color(r: 192, g: 68,  b: 143)),
        CrayolaColor(name: "Pink",         color: Color(r: 255, g: 170, b: 204)),
        CrayolaColor(name: "Brown",        color: Color(r: 180, g: 103, b: 77)),
        CrayolaColor(name: "Black",        color: Color(r: 35,  g: 35,  b: 35)),
        CrayolaColor(name: "White",        color: Color(r: 255, g: 254, b: 245)),
    ]
}

// MARK: - Brush Descriptor System

enum BrushBaseStyle: String, Codable, CaseIterable {
    case crayon, marker, chalk, patternStamp

    var icon: String {
        switch self {
        case .crayon:       return "🖍️"
        case .marker:       return "🖊️"
        case .chalk:        return "🩫"
        case .patternStamp: return "🔵"
        }
    }
}

enum PatternShape: String, Codable, CaseIterable {
    case star, heart, dot, circle, square, diamond, flower, triangle

    var icon: String {
        switch self {
        case .star:     return "⭐"
        case .heart:    return "❤️"
        case .dot:      return "•"
        case .circle:   return "⭕"
        case .square:   return "■"
        case .diamond:  return "◆"
        case .flower:   return "🌸"
        case .triangle: return "▲"
        }
    }

    var displayName: String { rawValue.capitalized }

    func path(center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch self {
        case .star:
            var p = Path()
            let total = 10
            for i in 0..<total {
                let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
                let rr: CGFloat = i % 2 == 0 ? r : r * 0.42
                let x = center.x + rr * CGFloat(cos(angle))
                let y = center.y + rr * CGFloat(sin(angle))
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else       { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            p.closeSubpath()
            return p
        case .dot, .circle:
            return Ellipse().path(in: CGRect(x: center.x - r, y: center.y - r,
                                             width: size, height: size))
        case .square:
            return Rectangle().path(in: CGRect(x: center.x - r, y: center.y - r,
                                               width: size, height: size))
        case .diamond:
            var p = Path()
            p.move(to:    CGPoint(x: center.x,     y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y))
            p.addLine(to: CGPoint(x: center.x,     y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y))
            p.closeSubpath()
            return p
        case .heart:
            let w = size, h = size
            let x = center.x - w / 2, y = center.y - h / 2
            var p = Path()
            p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85))
            p.addCurve(to: CGPoint(x: x, y: y + h * 0.35),
                       control1: CGPoint(x: x + w * 0.1, y: y + h * 0.70),
                       control2: CGPoint(x: x, y: y + h * 0.50))
            p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.25),
                     radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.25),
                     radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85),
                       control1: CGPoint(x: x + w, y: y + h * 0.50),
                       control2: CGPoint(x: x + w * 0.9, y: y + h * 0.70))
            p.closeSubpath()
            return p
        case .flower:
            var p = Path()
            let petalR = size * 0.28
            let orbit  = size * 0.24
            for i in 0..<6 {
                let angle = Double(i) / 6.0 * 2 * .pi
                let cx = center.x + CGFloat(cos(angle)) * orbit
                let cy = center.y + CGFloat(sin(angle)) * orbit
                p.addEllipse(in: CGRect(x: cx - petalR, y: cy - petalR,
                                        width: petalR * 2, height: petalR * 2))
            }
            let cr = petalR * 0.6
            p.addEllipse(in: CGRect(x: center.x - cr, y: center.y - cr,
                                    width: cr * 2, height: cr * 2))
            return p
        case .triangle:
            var p = Path()
            p.move(to:    CGPoint(x: center.x,     y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y + r))
            p.closeSubpath()
            return p
        }
    }
}

struct BrushDescriptor: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var baseStyle: BrushBaseStyle
    var patternShape: PatternShape?
    var stampSpacing: CGFloat        // multiplier of brushSize; range 0.5–3.0
    var sizeVariation: CGFloat       // 0.0 (uniform) → 1.0 (wild)
    var isSystem: Bool               // system brushes cannot be deleted from the pool

    // Fixed-UUID system brushes so slot UUIDs survive app restarts
    static let systemBrushes: [BrushDescriptor] = [
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                        name: "Crayon",   icon: "🖍️", baseStyle: .crayon,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                        name: "Marker",   icon: "🖊️", baseStyle: .marker,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                        name: "Sparkle",  icon: "✨", baseStyle: .patternStamp,
                        patternShape: .star, stampSpacing: 1.2, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                        name: "Chalk",    icon: "🩫", baseStyle: .chalk,
                        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                        name: "Hearts",   icon: "❤️", baseStyle: .patternStamp,
                        patternShape: .heart, stampSpacing: 1.3, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                        name: "Dots",     icon: "•",  baseStyle: .patternStamp,
                        patternShape: .dot, stampSpacing: 0.9, sizeVariation: 0.0, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                        name: "Flowers",  icon: "🌸", baseStyle: .patternStamp,
                        patternShape: .flower, stampSpacing: 1.4, sizeVariation: 0.2, isSystem: true),
        BrushDescriptor(id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
                        name: "Confetti", icon: "🎊", baseStyle: .patternStamp,
                        patternShape: .square, stampSpacing: 0.8, sizeVariation: 0.6, isSystem: true),
    ]

    // Used internally for eraser — never enters the pool
    static let eraser = BrushDescriptor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Eraser", icon: "⬜", baseStyle: .marker,
        patternShape: nil, stampSpacing: 1.0, sizeVariation: 0.0, isSystem: true
    )
}

// MARK: - Drawing Data

struct StrokePoint {
    let location: CGPoint
}

struct Stroke: Identifiable {
    let id = UUID()
    var points: [StrokePoint]
    let color: Color
    let brushSize: CGFloat
    let brush: BrushDescriptor          // was: brushType: BrushType
    let opacity: CGFloat
}

struct StampPlacement: Identifiable {
    let id = UUID()
    let emoji: String
    let location: CGPoint
    let size: CGFloat
}

// MARK: - Stamp Categories

struct StampCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let stamps: [String]
}

let allStampCategories: [StampCategory] = [
    StampCategory(name: "Animals", icon: "🐾", stamps: [
        "🐶","🐱","🐰","🦊","🐻","🐼","🐨","🐯",
        "🦁","🐮","🐷","🐸","🐵","🐔","🐧","🦆",
        "🐘","🦒","🦓","🦬","🐬","🐠","🦀","🐢"
    ]),
    StampCategory(name: "Insects", icon: "🦋", stamps: [
        "🦋","🐛","🐜","🐝","🪲","🐞","🦗","🕷️",
        "🪳","🦟","🪰","🪱","🦂","🐌","🦎","🐡"
    ]),
    StampCategory(name: "Plants", icon: "🌸", stamps: [
        "🌸","🌺","🌻","🌹","🌷","🌳","🌲","🌴",
        "🌵","🍀","🍁","🍃","🌿","🌱","🌾","🎋"
    ]),
    StampCategory(name: "Fun", icon: "⭐", stamps: [
        "⭐","🌈","☀️","🌙","❤️","🎈","🎀","🎁",
        "🏠","🚂","🚀","🦄","🍦","🍭","🎪","🎠"
    ]),
]

// MARK: - Drawing State (ObservableObject)

class DrawingState: ObservableObject {
    // Active settings
    @Published var selectedColor: Color  = CrayolaColor.palette[0].color
    @Published var backgroundColor: Color = Color(r: 255, g: 250, b: 235)
    @Published var brushSize: CGFloat   = 24
    @Published var brushOpacity: CGFloat = 1.0
    @Published var selectedBrush: BrushDescriptor = BrushDescriptor.systemBrushes[0]
    @Published var isEraserMode: Bool   = false
    @Published var selectedStamp: String = "🦋"
    @Published var isStampMode: Bool    = false

    // Brush pool & quick-access slots
    @Published var brushPool: [BrushDescriptor] = []
    @Published var slotAssignments: [UUID?] = [nil, nil, nil]

    // Drawing data
    @Published var strokes: [Stroke] = []
    @Published var stamps: [StampPlacement] = []
    @Published var currentStroke: Stroke? = nil

    // Undo stacks
    private var strokeHistory: [[Stroke]] = []
    private var stampHistory: [[StampPlacement]] = []

    init() {
        loadPersistedState()
    }

    // MARK: - Pool Management

    func addBrush(_ brush: BrushDescriptor) {
        brushPool.append(brush)
        persist()
    }

    func deleteBrush(id: UUID) {
        brushPool.removeAll { $0.id == id && !$0.isSystem }
        slotAssignments = slotAssignments.map { $0 == id ? nil : $0 }
        persist()
    }

    func assignBrush(id: UUID, toSlot slot: Int) {
        guard slot >= 0 && slot < 3 else { return }
        slotAssignments[slot] = id
        persist()
    }

    // MARK: - Stroke Actions

    func beginStroke(at point: CGPoint) {
        let brush   = isEraserMode ? BrushDescriptor.eraser : selectedBrush
        let color   = isEraserMode ? backgroundColor : selectedColor
        let opacity = isEraserMode ? 1.0 : brushOpacity
        currentStroke = Stroke(
            points:    [StrokePoint(location: point)],
            color:     color,
            brushSize: brushSize,
            brush:     brush,
            opacity:   opacity
        )
    }

    func continueStroke(at point: CGPoint) {
        currentStroke?.points.append(StrokePoint(location: point))
    }

    func endStroke() {
        guard let stroke = currentStroke else { return }
        strokeHistory.append(strokes)
        strokes.append(stroke)
        currentStroke = nil
        persistDrawing()
    }

    func placeStamp(at point: CGPoint) {
        stampHistory.append(stamps)
        stamps.append(StampPlacement(
            emoji: selectedStamp,
            location: point,
            size: brushSize * 2.8
        ))
        persistDrawing()
    }

    func undo() {
        if !strokeHistory.isEmpty { strokes = strokeHistory.removeLast() }
        if !stampHistory.isEmpty  { stamps  = stampHistory.removeLast()  }
        persistDrawing()
    }

    func clear() {
        strokeHistory.append(strokes)
        stampHistory.append(stamps)
        strokes = []
        stamps = []
        currentStroke = nil
        persistDrawing()
    }

    var canUndo: Bool { !strokeHistory.isEmpty || !stampHistory.isEmpty }

    // MARK: - Persistence

    private func loadPersistedState() {
        let userBrushes: [BrushDescriptor]
        if let data = UserDefaults.standard.data(forKey: "brushPool"),
           let decoded = try? JSONDecoder().decode([BrushDescriptor].self, from: data) {
            userBrushes = decoded
        } else {
            userBrushes = []
        }
        brushPool = BrushDescriptor.systemBrushes + userBrushes

        if let slotStrings = UserDefaults.standard.stringArray(forKey: "slotAssignments"),
           slotStrings.count == 3 {
            slotAssignments = slotStrings.map { $0.isEmpty ? nil : UUID(uuidString: $0) ?? nil }
        }

        let savedOpacity = CGFloat(UserDefaults.standard.double(forKey: "brushOpacity"))
        brushOpacity = savedOpacity > 0 ? savedOpacity : 1.0

        loadDrawing()
    }

    func persist() {
        let userBrushes = brushPool.filter { !$0.isSystem }
        if let data = try? JSONEncoder().encode(userBrushes) {
            UserDefaults.standard.set(data, forKey: "brushPool")
        }
        let slotStrings = slotAssignments.map { $0?.uuidString ?? "" }
        UserDefaults.standard.set(slotStrings, forKey: "slotAssignments")
        UserDefaults.standard.set(Double(brushOpacity), forKey: "brushOpacity")
    }

    private var drawingFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("currentDrawing.json")
    }

    func persistDrawing() {
        let snapshot = DrawingSnapshot(
            strokes:         strokes.map { CodableStroke($0) },
            stamps:          stamps.map  { CodableStampPlacement($0) },
            backgroundColor: CodableColor(backgroundColor)
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: drawingFileURL, options: .atomic)
        }
    }

    private func loadDrawing() {
        guard let data = try? Data(contentsOf: drawingFileURL),
              let snapshot = try? JSONDecoder().decode(DrawingSnapshot.self, from: data)
        else { return }
        strokes         = snapshot.strokes.map { $0.stroke }
        stamps          = snapshot.stamps.map  { $0.stampPlacement }
        backgroundColor = snapshot.backgroundColor.color
    }
}

// MARK: - Color Helper

extension Color {
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

// MARK: - Comparable Clamp Helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
