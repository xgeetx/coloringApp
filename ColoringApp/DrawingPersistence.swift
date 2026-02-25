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

// MARK: - Drawing Snapshot

struct DrawingSnapshot: Codable {
    let strokes:         [CodableStroke]
    let stamps:          [CodableStampPlacement]
    let backgroundColor: CodableColor
}
