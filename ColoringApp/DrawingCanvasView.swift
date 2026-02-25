import SwiftUI

// MARK: - Drawing Canvas

struct DrawingCanvasView: View {
    @ObservedObject var state: DrawingState
    var dismissFlyout: (() -> Void)? = nil
    @State private var lastMagnification: CGFloat = 1.0
    @State private var isPinching: Bool = false

    var body: some View {
        Canvas { ctx, size in
            // Background fill
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(state.backgroundColor)
            )

            // Committed strokes
            for stroke in state.strokes {
                render(stroke: stroke, in: ctx)
            }

            // In-progress stroke
            if let live = state.currentStroke {
                render(stroke: live, in: ctx)
            }

            // Stamps
            for stamp in state.stamps {
                let fontSize = stamp.size * 0.72
                let rect = CGRect(
                    x: stamp.location.x - stamp.size / 2,
                    y: stamp.location.y - stamp.size / 2,
                    width: stamp.size,
                    height: stamp.size
                )
                ctx.draw(
                    Text(stamp.emoji).font(.system(size: fontSize)),
                    in: rect
                )
            }
        }
        .contentShape(Rectangle())
        .gesture(drawGesture.simultaneously(with: pinchGesture))
    }

    // MARK: - Gesture

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isPinching else { return }
                if state.isStampMode {
                    return
                }
                if state.currentStroke == nil {
                    dismissFlyout?()
                    state.beginStroke(at: value.location)
                } else {
                    state.continueStroke(at: value.location)
                }
            }
            .onEnded { value in
                guard !isPinching else {
                    state.currentStroke = nil   // discard in-progress stroke
                    return
                }
                if state.isStampMode {
                    state.placeStamp(at: value.location)
                } else {
                    state.endStroke()
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                isPinching = true
                let delta = scale / lastMagnification
                lastMagnification = scale
                state.brushSize = (state.brushSize * delta).clamped(to: 6...80)
            }
            .onEnded { _ in
                lastMagnification = 1.0
                isPinching = false
            }
    }

    // MARK: - Rendering

    private func render(stroke: Stroke, in ctx: GraphicsContext) {
        guard !stroke.points.isEmpty else { return }

        // Eraser always hard-erases at full opacity (bypass layer)
        if stroke.brush.id == BrushDescriptor.eraser.id {
            renderHardErase(stroke, in: ctx)
            return
        }

        // Apply per-stroke opacity via a composited layer
        ctx.drawLayer { layerCtx in
            layerCtx.opacity = stroke.opacity
            switch stroke.brush.baseStyle {
            case .crayon:       renderCrayon(stroke, in: layerCtx)
            case .marker:       renderMarker(stroke, in: layerCtx)
            case .chalk:        renderChalk(stroke, in: layerCtx)
            case .patternStamp: renderPatternStamp(stroke, in: layerCtx)
            }
        }
    }

    private func renderCrayon(_ stroke: Stroke, in ctx: GraphicsContext) {
        // 5 passes: offset + varying opacity creates wax texture
        let offsets: [(CGFloat, CGFloat, Double)] = [
            (-2.5, -1.5, 0.50),
            (-1.0, -0.5, 0.65),
            ( 0.0,  0.0, 0.72),
            ( 1.0,  0.8, 0.60),
            ( 2.2,  1.5, 0.45),
        ]
        for (i, (dx, dy, opacity)) in offsets.enumerated() {
            var path = Path()
            let jitterX = deterministicJitter(index: i,       strokeHash: stroke.id.hashValue) * 1.5
            let jitterY = deterministicJitter(index: i + 100, strokeHash: stroke.id.hashValue) * 1.5
            let pts = stroke.points.map {
                CGPoint(x: $0.location.x + dx + jitterX, y: $0.location.y + dy + jitterY)
            }
            guard let first = pts.first else { continue }
            path.move(to: first)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            ctx.stroke(
                path,
                with: .color(stroke.color.opacity(opacity)),
                style: StrokeStyle(
                    lineWidth: stroke.brushSize * 0.85,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func renderMarker(_ stroke: Stroke, in ctx: GraphicsContext) {
        var path = Path()
        guard let first = stroke.points.first else { return }
        path.move(to: first.location)

        if stroke.points.count == 1 {
            // Dot
            let r = stroke.brushSize / 2
            let rect = CGRect(x: first.location.x - r, y: first.location.y - r, width: stroke.brushSize, height: stroke.brushSize)
            ctx.fill(Ellipse().path(in: rect), with: .color(stroke.color.opacity(0.75)))
            return
        }

        for pt in stroke.points.dropFirst() {
            path.addLine(to: pt.location)
        }
        ctx.stroke(
            path,
            with: .color(stroke.color.opacity(0.72)),
            style: StrokeStyle(
                lineWidth: stroke.brushSize * 1.6,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func renderHardErase(_ stroke: Stroke, in ctx: GraphicsContext) {
        var path = Path()
        guard let first = stroke.points.first else { return }
        path.move(to: first.location)

        if stroke.points.count == 1 {
            let r = stroke.brushSize / 2
            let rect = CGRect(x: first.location.x - r, y: first.location.y - r,
                              width: stroke.brushSize, height: stroke.brushSize)
            ctx.fill(Ellipse().path(in: rect), with: .color(stroke.color.opacity(1.0)))
            return
        }

        for pt in stroke.points.dropFirst() {
            path.addLine(to: pt.location)
        }
        ctx.stroke(
            path,
            with: .color(stroke.color.opacity(1.0)),
            style: StrokeStyle(lineWidth: stroke.brushSize * 1.6, lineCap: .round, lineJoin: .round)
        )
    }

    private func renderChalk(_ stroke: Stroke, in ctx: GraphicsContext) {
        let offsets: [(CGFloat, CGFloat, Double)] = [
            (-2.0, -1.5, 0.30),
            (-0.8, -0.5, 0.38),
            ( 0.0,  0.0, 0.42),
            ( 0.7,  1.0, 0.33),
            ( 1.8, -0.5, 0.28),
        ]
        for (dx, dy, opacity) in offsets {
            var path = Path()
            let pts = stroke.points.map { CGPoint(x: $0.location.x + dx, y: $0.location.y + dy) }
            guard let first = pts.first else { continue }
            path.move(to: first)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            ctx.stroke(path,
                       with: .color(stroke.color.opacity(opacity)),
                       style: StrokeStyle(lineWidth: stroke.brushSize * 0.65,
                                          lineCap: .round, lineJoin: .round))
        }
    }

    private func renderPatternStamp(_ stroke: Stroke, in ctx: GraphicsContext) {
        let shape = stroke.brush.patternShape ?? .dot
        let spacing = stroke.brush.stampSpacing * stroke.brushSize
        var lastPlaced: CGPoint? = nil

        for (index, pt) in stroke.points.enumerated() {
            if let last = lastPlaced {
                let dist = hypot(pt.location.x - last.x, pt.location.y - last.y)
                guard dist >= spacing else { continue }
            }
            lastPlaced = pt.location

            let jitter = deterministicJitter(index: index, strokeHash: stroke.id.hashValue)
            let size = stroke.brushSize * (1.0 + stroke.brush.sizeVariation * (jitter * 2.0 - 1.0))
            let stampPath = pathForShape(shape, center: pt.location, size: max(4, size))
            ctx.fill(stampPath, with: .color(stroke.color))

            // white center glint (kept from original Sparkle)
            if shape == .star {
                let glintR = size * 0.09
                let glintRect = CGRect(x: pt.location.x - glintR, y: pt.location.y - glintR,
                                       width: glintR * 2, height: glintR * 2)
                ctx.fill(Ellipse().path(in: glintRect), with: .color(.white.opacity(0.8)))
            }
        }
    }

    private func deterministicJitter(index: Int, strokeHash: Int) -> CGFloat {
        let h = (strokeHash ^ (index &* 2654435761)) & 0x7FFF_FFFF
        return CGFloat(h % 1000) / 1000.0
    }

    // MARK: - Shape Dispatchers

    private func pathForShape(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch shape {
        case .star:
            return makeStar(center: center, outerR: r, innerR: r * 0.42, points: 5)
        case .dot, .circle:
            return Ellipse().path(in: CGRect(x: center.x - r, y: center.y - r, width: size, height: size))
        case .square:
            return Rectangle().path(in: CGRect(x: center.x - r, y: center.y - r, width: size, height: size))
        case .diamond:
            return makeDiamond(center: center, size: size)
        case .heart:
            return makeHeart(center: center, size: size)
        case .flower:
            return makeFlower(center: center, size: size)
        case .triangle:
            return makeTriangle(center: center, size: size)
        }
    }

    // MARK: - Shape Path Helpers

    private func makeStar(center: CGPoint, outerR: CGFloat, innerR: CGFloat, points: Int) -> Path {
        var path = Path()
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let r: CGFloat = i % 2 == 0 ? outerR : innerR
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    private func makeDiamond(center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        var p = Path()
        p.move(to:    CGPoint(x: center.x,     y: center.y - r))
        p.addLine(to: CGPoint(x: center.x + r, y: center.y))
        p.addLine(to: CGPoint(x: center.x,     y: center.y + r))
        p.addLine(to: CGPoint(x: center.x - r, y: center.y))
        p.closeSubpath()
        return p
    }

    private func makeTriangle(center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        var p = Path()
        p.move(to:    CGPoint(x: center.x,     y: center.y - r))
        p.addLine(to: CGPoint(x: center.x + r, y: center.y + r))
        p.addLine(to: CGPoint(x: center.x - r, y: center.y + r))
        p.closeSubpath()
        return p
    }

    private func makeHeart(center: CGPoint, size: CGFloat) -> Path {
        // Two arcs for the lobes, curve to a point at the bottom
        let w = size, h = size
        let x = center.x - w / 2, y = center.y - h / 2
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85))
        p.addCurve(
            to:       CGPoint(x: x,          y: y + h * 0.35),
            control1: CGPoint(x: x + w * 0.1, y: y + h * 0.70),
            control2: CGPoint(x: x,           y: y + h * 0.50)
        )
        p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.25),
                 radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.25),
                 radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(
            to:       CGPoint(x: x + w * 0.5, y: y + h * 0.85),
            control1: CGPoint(x: x + w,        y: y + h * 0.50),
            control2: CGPoint(x: x + w * 0.9,  y: y + h * 0.70)
        )
        p.closeSubpath()
        return p
    }

    private func makeFlower(center: CGPoint, size: CGFloat) -> Path {
        // 6 petal circles orbiting a center circle
        var p = Path()
        let petalR = size * 0.28
        let orbit  = size * 0.24
        for i in 0..<6 {
            let angle = Double(i) / 6.0 * 2 * .pi
            let cx = center.x + CGFloat(cos(angle)) * orbit
            let cy = center.y + CGFloat(sin(angle)) * orbit
            p.addEllipse(in: CGRect(x: cx - petalR, y: cy - petalR, width: petalR * 2, height: petalR * 2))
        }
        let cr = petalR * 0.6
        p.addEllipse(in: CGRect(x: center.x - cr, y: center.y - cr, width: cr * 2, height: cr * 2))
        return p
    }
}
