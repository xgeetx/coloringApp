import SwiftUI

// MARK: - Drawing Canvas

struct DrawingCanvasView: View {
    @ObservedObject var state: DrawingState
    var dismissFlyout: (() -> Void)? = nil
    @State private var lastMagnification: CGFloat = 1.0
    @State private var isPinching: Bool = false

    var body: some View {
        Canvas { ctx, size in
            // 1. Background fill
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(state.backgroundColor)
            )

            // 2. Drawing elements
            if state.stampsAlwaysOnTop {
                // Stamps-on-top mode: all strokes first, then all stamps
                for element in state.drawingElements {
                    if case .stroke(let stroke) = element {
                        render(stroke: stroke, in: ctx)
                    }
                }
                for element in state.drawingElements {
                    if case .stamp(let stamp) = element {
                        renderStamp(stamp, in: ctx)
                    }
                }
            } else {
                // Creation-order mode: render in order
                for element in state.drawingElements {
                    switch element {
                    case .stroke(let stroke):
                        render(stroke: stroke, in: ctx)
                    case .stamp(let stamp):
                        renderStamp(stamp, in: ctx)
                    }
                }
            }

            // 3. In-progress stroke (topmost)
            if let live = state.currentStroke {
                render(stroke: live, in: ctx)
            }
        }
        .contentShape(Rectangle())
        .gesture(drawGesture.simultaneously(with: pinchGesture))
        .overlay {
            if isPinching {
                if state.isStampMode {
                    Text(state.selectedStamp)
                        .font(.system(size: state.brushSize * 2.8 * 0.72))
                        .opacity(0.5)
                        .allowsHitTesting(false)
                } else {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 2)
                        .frame(width: state.brushSize, height: state.brushSize)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Gesture

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isPinching else { return }
                if state.isStampMode {
                    return
                }
                // Eraser hit-test: remove any stamp under the eraser tip
                if state.isEraserMode {
                    let r = state.brushSize / 2
                    for stamp in state.stamps {
                        let half = stamp.size / 2
                        let hitRect = CGRect(
                            x: stamp.location.x - half - r,
                            y: stamp.location.y - half - r,
                            width: stamp.size + r * 2,
                            height: stamp.size + r * 2
                        )
                        if hitRect.contains(value.location) {
                            state.removeStamp(id: stamp.id)
                        }
                    }
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

    private func renderStamp(_ stamp: StampPlacement, in ctx: GraphicsContext) {
        let fontSize = stamp.size * 0.72
        let rect = CGRect(
            x: stamp.location.x - stamp.size / 2,
            y: stamp.location.y - stamp.size / 2,
            width: stamp.size,
            height: stamp.size
        )
        ctx.drawLayer { layerCtx in
            layerCtx.opacity = stamp.opacity
            layerCtx.draw(
                Text(stamp.emoji).font(.system(size: fontSize)),
                in: rect
            )
        }
    }

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
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
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
                with: .color(stroke.color.opacity(min(opacity * opacityScale, 1.0))),
                style: StrokeStyle(
                    lineWidth: stroke.brushSize * 0.85,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        // Paper grain stipple — dots scattered within stroke width
        // Uses index range 500+ to avoid collision with pass jitter indices (0–4, 100–104)
        // For user brushes, stampSpacing controls grain spread (0.5=tight, 1.0=default, 3.0=chunky)
        let spread = stroke.brushSize * (stroke.brush.isSystem ? 0.45 : 0.45 * stroke.brush.stampSpacing)
        let hash   = stroke.id.hashValue
        for (i, pt) in stroke.points.enumerated() where i % 2 == 0 {
            let si = i / 2
            let ox = (deterministicJitter(index: 500 + si * 4,     strokeHash: hash) * 2 - 1) * spread
            let oy = (deterministicJitter(index: 500 + si * 4 + 1, strokeHash: hash) * 2 - 1) * spread
            let r  =  0.5 + deterministicJitter(index: 500 + si * 4 + 2, strokeHash: hash) * 2.0
            let op =  0.04 + deterministicJitter(index: 500 + si * 4 + 3, strokeHash: hash) * 0.18
            let x  = pt.location.x + ox
            let y  = pt.location.y + oy
            ctx.fill(
                Ellipse().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(stroke.color.opacity(op))
            )
        }
    }

    private func renderMarker(_ stroke: Stroke, in ctx: GraphicsContext) {
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
        guard let first = stroke.points.first else { return }

        if stroke.points.count == 1 {
            // Dot: halo ring then solid fill
            let r = stroke.brushSize / 2
            ctx.fill(
                Ellipse().path(in: CGRect(x: first.location.x - r * 1.6,
                                          y: first.location.y - r * 1.6,
                                          width: stroke.brushSize * 1.6 * 2,
                                          height: stroke.brushSize * 1.6 * 2)),
                with: .color(stroke.color.opacity(0.08))
            )
            ctx.fill(
                Ellipse().path(in: CGRect(x: first.location.x - r,
                                          y: first.location.y - r,
                                          width: stroke.brushSize,
                                          height: stroke.brushSize)),
                with: .color(stroke.color.opacity(min(0.82 * opacityScale, 1.0)))
            )
            return
        }

        // Halo pass — wide, very transparent (ink bleed)
        var haloPath = Path()
        haloPath.move(to: first.location)
        for pt in stroke.points.dropFirst() { haloPath.addLine(to: pt.location) }
        ctx.stroke(haloPath,
                   with: .color(stroke.color.opacity(0.08)),
                   style: StrokeStyle(lineWidth: stroke.brushSize * 2.2,
                                      lineCap: .round, lineJoin: .round))

        // Solid pass — clean, saturated, no texture
        var path = Path()
        path.move(to: first.location)
        for pt in stroke.points.dropFirst() { path.addLine(to: pt.location) }
        ctx.stroke(path,
                   with: .color(stroke.color.opacity(min(0.82 * opacityScale, 1.0))),
                   style: StrokeStyle(lineWidth: stroke.brushSize * 1.5,
                                      lineCap: .round, lineJoin: .round))
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
        let opacityScale = stroke.brush.isSystem
            ? 1.0
            : Double((0.4 + stroke.brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
        let spread = stroke.brushSize * (stroke.brush.isSystem ? 0.6 : 0.6 * stroke.brush.stampSpacing)
        let hash   = stroke.id.hashValue
        for (i, pt) in stroke.points.enumerated() {
            for j in 0..<5 {
                let idx = i * 5 + j
                let ox  = (deterministicJitter(index: idx * 4,     strokeHash: hash) * 2 - 1) * spread
                let oy  = (deterministicJitter(index: idx * 4 + 1, strokeHash: hash) * 2 - 1) * spread
                let r   =  1.0 + deterministicJitter(index: idx * 4 + 2, strokeHash: hash) * 4.0
                let op  =  0.08 + deterministicJitter(index: idx * 4 + 3, strokeHash: hash) * 0.20
                let x   = pt.location.x + ox
                let y   = pt.location.y + oy
                ctx.fill(
                    Ellipse().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(stroke.color.opacity(min(op * opacityScale, 1.0)))
                )
            }
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
        shape.path(center: center, size: size)
    }
}
