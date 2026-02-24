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

    init(_ stroke: Stroke) {
        points    = stroke.points.map { CodableStrokePoint($0) }
        color     = CodableColor(stroke.color)
        brushSize = Double(stroke.brushSize)
        brush     = stroke.brush
    }

    var stroke: Stroke {
        Stroke(
            points:    points.map { $0.strokePoint },
            color:     color.color,
            brushSize: CGFloat(brushSize),
            brush:     brush
        )
    }
}

// MARK: - Codable Stamp Placement

struct CodableStampPlacement: Codable {
    let emoji: String
    let x, y, size: Double

    init(_ stamp: StampPlacement) {
        emoji = stamp.emoji
        x     = Double(stamp.location.x)
        y     = Double(stamp.location.y)
        size  = Double(stamp.size)
    }

    var stampPlacement: StampPlacement {
        StampPlacement(
            emoji:    emoji,
            location: CGPoint(x: x, y: y),
            size:     CGFloat(size)
        )
    }
}

// MARK: - Drawing Snapshot

struct DrawingSnapshot: Codable {
    let strokes:         [CodableStroke]
    let stamps:          [CodableStampPlacement]
    let backgroundColor: CodableColor
}
