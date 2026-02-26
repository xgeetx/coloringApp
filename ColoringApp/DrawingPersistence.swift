import SwiftUI

// MARK: - Codable Color Bridge

struct CodableColor: Codable {
    let r, g, b, a: Double

    init(_ color: Color) {
        let ui = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        (r, g, b, a) = (Double(red), Double(green), Double(blue), Double(alpha))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

// MARK: - Codable Stroke Point

struct CodableStrokePoint: Codable {
    let x, y: Double

    init(_ point: StrokePoint) {
        x = Double(point.location.x)
        y = Double(point.location.y)
    }

    var strokePoint: StrokePoint {
        StrokePoint(location: CGPoint(x: x, y: y))
    }
}

// MARK: - Codable Stroke

struct CodableStroke: Codable {
    let points: [CodableStrokePoint]
    let color: CodableColor
    let brushSize: Double
    let brush: BrushDescriptor   // already Codable
    let opacity: Double

    init(_ stroke: Stroke) {
        points    = stroke.points.map { CodableStrokePoint($0) }
        color     = CodableColor(stroke.color)
        brushSize = Double(stroke.brushSize)
        brush     = stroke.brush
        opacity   = Double(stroke.opacity)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points    = try container.decode([CodableStrokePoint].self, forKey: .points)
        color     = try container.decode(CodableColor.self, forKey: .color)
        brushSize = try container.decode(Double.self, forKey: .brushSize)
        brush     = try container.decode(BrushDescriptor.self, forKey: .brush)
        opacity   = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }

    var stroke: Stroke {
        Stroke(
            points:    points.map { $0.strokePoint },
            color:     color.color,
            brushSize: CGFloat(brushSize),
            brush:     brush,
            opacity:   CGFloat(opacity)
        )
    }
}

// MARK: - Codable Stamp Placement

struct CodableStampPlacement: Codable {
    let emoji: String
    let x, y, size: Double
    let opacity: Double

    init(_ stamp: StampPlacement) {
        emoji   = stamp.emoji
        x       = Double(stamp.location.x)
        y       = Double(stamp.location.y)
        size    = Double(stamp.size)
        opacity = stamp.opacity
    }

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        emoji   = try c.decode(String.self,  forKey: .emoji)
        x       = try c.decode(Double.self,  forKey: .x)
        y       = try c.decode(Double.self,  forKey: .y)
        size    = try c.decode(Double.self,  forKey: .size)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }

    var stampPlacement: StampPlacement {
        StampPlacement(
            emoji:    emoji,
            location: CGPoint(x: x, y: y),
            size:     CGFloat(size),
            opacity:  opacity
        )
    }
}

// MARK: - Codable Drawing Element

enum CodableDrawingElement: Codable {
    case stroke(CodableStroke)
    case stamp(CodableStampPlacement)

    enum CodingKeys: String, CodingKey { case type, data }

    init(_ element: DrawingElement) {
        switch element {
        case .stroke(let s): self = .stroke(CodableStroke(s))
        case .stamp(let s):  self = .stamp(CodableStampPlacement(s))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stroke(let s):
            try c.encode("stroke", forKey: .type)
            try c.encode(s, forKey: .data)
        case .stamp(let s):
            try c.encode("stamp", forKey: .type)
            try c.encode(s, forKey: .data)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "stroke": self = .stroke(try c.decode(CodableStroke.self, forKey: .data))
        case "stamp":  self = .stamp(try c.decode(CodableStampPlacement.self, forKey: .data))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown element type: \(type)")
        }
    }

    var element: DrawingElement {
        switch self {
        case .stroke(let s): return .stroke(s.stroke)
        case .stamp(let s):  return .stamp(s.stampPlacement)
        }
    }
}

// MARK: - Drawing Snapshot

struct DrawingSnapshot: Codable {
    // New unified format
    let elements: [CodableDrawingElement]?
    // Legacy format (kept for backward compat decoding)
    let strokes: [CodableStroke]?
    let stamps: [CodableStampPlacement]?
    let backgroundColor: CodableColor

    enum CodingKeys: String, CodingKey {
        case elements, strokes, stamps, backgroundColor
    }

    // Encode always uses new format
    init(elements: [CodableDrawingElement], backgroundColor: CodableColor) {
        self.elements = elements
        self.strokes = nil
        self.stamps = nil
        self.backgroundColor = backgroundColor
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(elements, forKey: .elements)
        try c.encode(backgroundColor, forKey: .backgroundColor)
    }

    // Decode handles both old and new
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = try c.decode(CodableColor.self, forKey: .backgroundColor)
        elements = try c.decodeIfPresent([CodableDrawingElement].self, forKey: .elements)
        strokes  = try c.decodeIfPresent([CodableStroke].self, forKey: .strokes)
        stamps   = try c.decodeIfPresent([CodableStampPlacement].self, forKey: .stamps)
    }

    /// Returns unified drawing elements — handles legacy and new format
    var drawingElements: [DrawingElement] {
        if let elements = elements {
            return elements.map { $0.element }
        }
        // Legacy: stamps first (old render order), then strokes
        var result: [DrawingElement] = []
        if let stamps = stamps {
            result += stamps.map { .stamp($0.stampPlacement) }
        }
        if let strokes = strokes {
            result += strokes.map { .stroke($0.stroke) }
        }
        return result
    }
}
