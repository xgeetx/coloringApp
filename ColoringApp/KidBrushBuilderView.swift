import SwiftUI

// MARK: - Kid Brush Builder Sheet

struct KidBrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedTexture: BrushBaseStyle = .crayon
    @State private var intensity: CGFloat = 0.5      // 0.0=soft, 1.0=bold (crayon/marker/chalk)
    @State private var grainSpread: CGFloat = 1.0    // 0.5=tight, 3.0=spread (crayon only → stampSpacing)
    @State private var stampSpacing: CGFloat = 1.2   // dense←→spread (glitter)
    @State private var previewPoints: [CGPoint] = []

    private let textures: [BrushBaseStyle] = [.crayon, .marker, .chalk, .patternStamp]
    private let brushSize: CGFloat = 24

    private var userBrushes: [BrushDescriptor] {
        state.brushPool.filter { !$0.isSystem }
    }

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
            .padding(.bottom, 8)

            // ── Delete Row: show existing user brushes with × button ──
            if !userBrushes.isEmpty {
                HStack(spacing: 12) {
                    Text("My Brushes:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(userBrushes) { brush in
                        ZStack(alignment: .topTrailing) {
                            KidBrushPreview(brush: brush, color: state.selectedColor)
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1.5)
                                )
                            Button {
                                state.deleteBrush(id: brush.id)
                                if state.selectedBrush.id == brush.id,
                                   let first = state.brushPool.first {
                                    state.selectedBrush = first
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white, .red)
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

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
                            renderPreview(ctx: ctx)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in previewPoints.append(v.location) }
                        .onEnded   { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) { previewPoints = [] }
                            }
                        }
                )
            }
            .frame(height: 160)
            .padding(.horizontal, 24)
            .onChange(of: selectedTexture) { _ in previewPoints = [] }
            .onChange(of: intensity)       { _ in previewPoints = [] }
            .onChange(of: grainSpread)     { _ in previewPoints = [] }
            .onChange(of: stampSpacing)    { _ in previewPoints = [] }

            // ── Texture Picker ──
            VStack(spacing: 10) {
                Text("Pick a texture")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)

                HStack(spacing: 8) {
                    ForEach(textures, id: \.self) { texture in
                        KidTexturePickerTile(
                            style: texture,
                            isSelected: selectedTexture == texture,
                            previewColor: state.selectedColor
                        ) {
                            selectedTexture = texture
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── Contextual Sliders ──
            VStack(spacing: 6) {
                if selectedTexture == .patternStamp {
                    Slider(value: $stampSpacing, in: 0.5...3.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("dense").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("spread").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                } else if selectedTexture == .chalk {
                    // Slider 1: soft ↔ bold
                    Slider(value: $intensity, in: 0.0...1.0)
                        .tint(.blue)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("soft").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("bold").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                    // Slider 2: tight ↔ spread grain
                    Slider(value: $grainSpread, in: 0.5...3.0)
                        .tint(.brown)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("tight grain").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("spread grain").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                } else {
                    Slider(value: $intensity, in: 0.0...1.0)
                        .tint(.purple)
                        .padding(.horizontal, 24)
                    HStack {
                        Text("soft").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("bold").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.top, 16)

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

    // MARK: - Live Canvas Rendering

    private func renderPreview(ctx: GraphicsContext) {
        let color = state.selectedColor
        // shared rng helper — same seed logic as KidBrushPreview / DrawingCanvasView
        func rng(_ s: Int, _ i: Int) -> CGFloat {
            let h = (s ^ (i &* 2654435761)) & 0x7FFF_FFFF
            return CGFloat(h % 10000) / 10000.0
        }
        let seed = 42

        switch selectedTexture {
        case .crayon:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            let offsets: [(CGFloat, CGFloat, Double)] = [
                (-2.5,-1.5,0.50),(-1.0,-0.5,0.65),(0,0,0.72),(1.0,0.8,0.60),(2.2,1.5,0.45)
            ]
            for (dx, dy, op) in offsets {
                var path = Path()
                let pts = previewPoints.map { CGPoint(x: $0.x+dx, y: $0.y+dy) }
                guard let f = pts.first else { continue }
                path.move(to: f); pts.dropFirst().forEach { path.addLine(to: $0) }
                ctx.stroke(path, with: .color(color.opacity(min(op*scale,1.0))),
                           style: StrokeStyle(lineWidth: brushSize*0.85, lineCap:.round, lineJoin:.round))
            }
            // Grain stipple scaled by grainSpread
            let spread = brushSize * 0.45 * grainSpread
            for (i, pt) in previewPoints.enumerated() where i % 2 == 0 {
                let si = i / 2
                let ox = (rng(seed, 500 + si*4)     * 2 - 1) * spread
                let oy = (rng(seed, 500 + si*4 + 1) * 2 - 1) * spread
                let r  =  0.5 + rng(seed, 500 + si*4 + 2) * 2.0
                let op =  0.04 + rng(seed, 500 + si*4 + 3) * 0.18
                ctx.fill(Ellipse().path(in: CGRect(x: pt.x+ox-r, y: pt.y+oy-r, width: r*2, height: r*2)),
                         with: .color(color.opacity(op)))
            }

        case .marker:
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            var path = Path()
            guard let f = previewPoints.first else { return }
            path.move(to: f); previewPoints.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(0.72*scale,1.0))),
                       style: StrokeStyle(lineWidth: brushSize*1.6, lineCap:.round, lineJoin:.round))

        case .chalk:
            // Particle cloud matching DrawingCanvasView.renderChalk
            let scale = Double((0.4 + intensity * 1.2).clamped(to: 0.1...1.6))
            let cSpread = brushSize * 0.6 * grainSpread
            for (i, pt) in previewPoints.enumerated() {
                for j in 0..<5 {
                    let idx = i * 5 + j
                    let ox  = (rng(seed, idx*4)     * 2 - 1) * cSpread
                    let oy  = (rng(seed, idx*4 + 1) * 2 - 1) * cSpread
                    let r   =  1.0 + rng(seed, idx*4 + 2) * 4.0
                    let op  =  0.08 + rng(seed, idx*4 + 3) * 0.20
                    ctx.fill(
                        Ellipse().path(in: CGRect(x: pt.x+ox-r, y: pt.y+oy-r, width: r*2, height: r*2)),
                        with: .color(color.opacity(min(Double(op)*scale, 1.0)))
                    )
                }
            }

        case .patternStamp:
            let spacing = stampSpacing * brushSize
            var last: CGPoint? = nil
            for pt in previewPoints {
                if let l = last, hypot(pt.x-l.x, pt.y-l.y) < spacing { continue }
                last = pt
                ctx.fill(PatternShape.star.path(center: pt, size: brushSize),
                         with: .color(color))
                let glintR = brushSize * 0.09
                ctx.fill(Ellipse().path(in: CGRect(x: pt.x-glintR, y: pt.y-glintR,
                                                   width: glintR*2, height: glintR*2)),
                         with: .color(.white.opacity(0.8)))
            }
        }
    }

    // MARK: - Save

    private func save() {
        let textureName: String
        switch selectedTexture {
        case .crayon:       textureName = "Crayon"
        case .marker:       textureName = "Marker"
        case .chalk:        textureName = "Chalk"
        case .patternStamp: textureName = "Glitter"
        }
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: "My \(textureName)",
            icon: selectedTexture.icon,
            baseStyle: selectedTexture,
            patternShape: selectedTexture == .patternStamp ? .star : nil,
            stampSpacing: selectedTexture == .patternStamp ? stampSpacing
                        : selectedTexture == .chalk        ? grainSpread
                        : 1.0,
            sizeVariation: selectedTexture != .patternStamp ? intensity : 0.0,
            isSystem: false
        )
        // Cap at 2: remove oldest user brush first if already at limit
        let userBrushes = state.brushPool.filter { !$0.isSystem }
        if userBrushes.count >= 2, let oldest = userBrushes.first {
            state.deleteBrush(id: oldest.id)
        }
        state.addBrush(descriptor)
        state.selectedBrush = descriptor
        state.isEraserMode  = false
        state.isStampMode   = false
        dismiss()
    }
}

// MARK: - Texture Picker Tile

struct KidTexturePickerTile: View {
    let style: BrushBaseStyle
    let isSelected: Bool
    let previewColor: Color
    let action: () -> Void

    private var sampleBrush: BrushDescriptor {
        BrushDescriptor(
            id: UUID(), name: "", icon: "",
            baseStyle: style,
            patternShape: style == .patternStamp ? .star : nil,
            stampSpacing: 1.2, sizeVariation: 0.5, isSystem: true
        )
    }

    private var styleName: String {
        switch style {
        case .crayon:       return "Crayon"
        case .marker:       return "Marker"
        case .chalk:        return "Chalk"
        case .patternStamp: return "Glitter"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                KidBrushPreview(brush: sampleBrush, color: previewColor)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(styleName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}
