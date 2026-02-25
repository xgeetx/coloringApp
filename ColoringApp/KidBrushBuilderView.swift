import SwiftUI

// MARK: - Kid Brush Builder Sheet

struct KidBrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedShape: PatternShape = .star
    @State private var stampSpacing: CGFloat = 1.2
    @State private var previewPoints: [CGPoint] = []

    // Quick-access shapes for the kid picker
    private let shapes: [PatternShape] = [.star, .heart, .flower, .diamond, .dot]

    private let brushSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──
            HStack {
                Text("🔮 Make a Brush!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // ── Live Preview Canvas ──
            GeometryReader { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 6)

                    if previewPoints.isEmpty {
                        Text("Draw here to try your brush!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.5))
                    } else {
                        Canvas { ctx, _ in
                            let spacing = stampSpacing * brushSize
                            var lastPlaced: CGPoint? = nil
                            for pt in previewPoints {
                                if let last = lastPlaced {
                                    let dist = hypot(pt.x - last.x, pt.y - last.y)
                                    guard dist >= spacing else { continue }
                                }
                                lastPlaced = pt
                                let path = kidShapePath(selectedShape, center: pt, size: brushSize)
                                ctx.fill(path, with: .color(state.selectedColor))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in previewPoints.append(v.location) }
                        .onEnded   { _ in
                            // Clear after 1.5 s so user can try again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) { previewPoints = [] }
                            }
                        }
                )
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
            .onChange(of: selectedShape)  { _ in previewPoints = [] }
            .onChange(of: stampSpacing)   { _ in previewPoints = [] }

            // ── Shape Picker ──
            VStack(spacing: 10) {
                Text("Pick a shape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                HStack(spacing: 12) {
                    ForEach(shapes, id: \.self) { shape in
                        Button(action: { selectedShape = shape }) {
                            Text(shape.icon)
                                .font(.system(size: 38))
                                .frame(width: 64, height: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedShape == shape
                                              ? Color.accentColor.opacity(0.22)
                                              : Color.gray.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(
                                                    selectedShape == shape ? Color.accentColor : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(selectedShape == shape ? 1.10 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedShape)
                    }
                }
            }

            // ── Spread Slider ──
            VStack(spacing: 6) {
                Slider(value: $stampSpacing, in: 0.5...3.0)
                    .tint(.purple)
                    .padding(.horizontal, 24)
                HStack {
                    Text("close together")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("spread out")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 20)

            Spacer()

            // ── Save Button ──
            Button(action: save) {
                Text("✅  Use This Brush!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.4), radius: 8)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .kidSheetDetents()
        .kidDragIndicator()
    }

    // MARK: - Helpers

    private func save() {
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: "My \(selectedShape.displayName)s",
            icon: selectedShape.icon,
            baseStyle: .patternStamp,
            patternShape: selectedShape,
            stampSpacing: stampSpacing,
            sizeVariation: 0.0,
            isSystem: false
        )
        state.addBrush(descriptor)
        dismiss()
    }

    /// Minimal shape path renderer for the live preview (mirrors DrawingCanvasView logic).
    private func kidShapePath(_ shape: PatternShape, center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        switch shape {
        case .star:
            return makeStar(center: center, outerR: r, innerR: r * 0.42, points: 5)
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

    private func makeStar(center: CGPoint, outerR: CGFloat, innerR: CGFloat, points: Int) -> Path {
        var path = Path()
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let rr: CGFloat = i % 2 == 0 ? outerR : innerR
            let x = center.x + rr * CGFloat(cos(angle))
            let y = center.y + rr * CGFloat(sin(angle))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}
