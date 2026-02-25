import SwiftUI

// MARK: - Kid Mode Root View

struct KidContentView: View {
    @StateObject private var state = DrawingState()
    @State private var showMoreStamps  = false
    @State private var showKidBuilder  = false

    // Texture-only brushes for the kid strip (no pattern-stamp icon brushes)
    private var textureBrushes: [BrushDescriptor] {
        let textureStyles: Set<BrushBaseStyle> = [.crayon, .marker, .chalk]
        let systemTexture = BrushDescriptor.systemBrushes.filter {
            textureStyles.contains($0.baseStyle) || $0.name == "Sparkle"
        }
        let userBrushes = state.brushPool.filter { !$0.isSystem }
        return systemTexture + userBrushes
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(r: 255, g: 200, b: 220),
                    Color(r: 255, g: 230, b: 180),
                    Color(r: 200, g: 230, b: 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {

                // ── Top Toolbar ──
                KidTopToolbarView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // ── Main Row: Brush Strip | Canvas | Stamp Grid ──
                HStack(alignment: .top, spacing: 8) {

                    // Left: texture brushes
                    KidBrushStripView(
                        state: state,
                        brushes: textureBrushes,
                        onBuildBrush: { showKidBuilder = true }
                    )
                    .frame(width: 84)

                    // Centre: canvas
                    ZStack {
                        DrawingCanvasView(state: state)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)

                        // Stamp mode banner
                        if state.isStampMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    Label("Tap to stamp  \(state.selectedStamp)", systemImage: "hand.tap.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color.purple.opacity(0.85)))
                                    Spacer()
                                }
                                .padding(.top, 12)
                                Spacer()
                            }
                        }
                    }

                    // Right: quick stamp grid
                    KidStampGridView(state: state, onMoreTapped: { showMoreStamps = true })
                        .frame(width: 100)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)

                // ── Bottom: colour palette ──
                ColorPaletteView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showKidBuilder) {
            KidBrushBuilderView(state: state)
        }
        .sheet(isPresented: $showMoreStamps) {
            // Reuse existing stamps flyout; dismiss = close sheet
            StampsFlyoutView(state: state, onDismiss: { showMoreStamps = false })
                .kidSheetDetents()
        }
    }
}

// MARK: - Kid Top Toolbar

struct KidTopToolbarView: View {
    @ObservedObject var state: DrawingState
    @State private var showClearConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            KidToolbarButton(icon: "arrow.uturn.backward", label: "Undo",  color: .blue,
                             disabled: !state.canUndo) { state.undo() }

            KidToolbarButton(
                icon: "eraser.fill", label: "Erase",
                color: .orange, disabled: false,
                isActive: state.isEraserMode
            ) {
                state.isEraserMode.toggle()
                if state.isEraserMode { state.isStampMode = false }
            }

            Spacer()

            KidToolbarButton(icon: "trash", label: "Clear", color: .red, disabled: false) {
                showClearConfirm = true
            }
            .confirmationDialog("Clear the whole drawing?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear It! 🗑️", role: .destructive) { state.clear() }
                Button("Keep It! 🎨", role: .cancel) {}
            }

            KidToolbarButton(icon: "house.fill", label: "Home", color: .indigo, disabled: false) {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
    }
}

struct KidToolbarButton: View {
    let icon: String
    let label: String
    let color: Color
    let disabled: Bool
    var isActive: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            action()
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(disabled ? Color.gray : (isActive ? Color.white : color))
            .frame(width: 64, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(disabled ? Color.gray.opacity(0.08)
                          : (isActive ? color : color.opacity(0.15)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isActive ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Kid Brush Strip (left panel)

struct KidBrushStripView: View {
    @ObservedObject var state: DrawingState
    let brushes: [BrushDescriptor]
    let onBuildBrush: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(brushes) { brush in
                    KidBrushButton(
                        brush: brush,
                        isSelected: !state.isStampMode && !state.isEraserMode
                                    && state.selectedBrush.id == brush.id,
                        color: state.selectedColor
                    ) {
                        state.selectedBrush = brush
                        state.isStampMode   = false
                        state.isEraserMode  = false
                    }
                }

                Divider().padding(.horizontal, 6)

                // Build a Brush button
                Button(action: onBuildBrush) {
                    VStack(spacing: 4) {
                        Text("🔮")
                            .font(.system(size: 30))
                        Text("Make")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.purple.opacity(0.3),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.14), radius: 8)
        )
    }
}

struct KidBrushButton: View {
    let brush: BrushDescriptor
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                KidBrushPreview(brush: brush, color: color)
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                Text(brush.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.white.opacity(0.7))
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : .clear,
                            radius: 6)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Kid Stamp Grid (right panel)

/// Shows the first 8 stamps from the first category, plus a "More" button.
struct KidStampGridView: View {
    @ObservedObject var state: DrawingState
    let onMoreTapped: () -> Void

    // Fixed 8 quick-access stamps — first 8 animals
    private let quickStamps: [String] = Array(
        (allStampCategories.first?.stamps ?? []).prefix(8)
    )

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(quickStamps, id: \.self) { emoji in
                    Button(action: {
                        state.selectedStamp = emoji
                        state.isStampMode   = true
                        state.isEraserMode  = false
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    state.selectedStamp == emoji && state.isStampMode
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.white.opacity(0.7)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            state.selectedStamp == emoji && state.isStampMode
                                            ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            Text(emoji)
                                .font(.system(size: 28))
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // "More" button
            Button(action: onMoreTapped) {
                Label("More", systemImage: "chevron.down.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.14), radius: 8)
        )
    }
}

// MARK: - iOS 16+ Sheet Helpers

extension View {
    /// Applies presentationDetents([.medium, .large]) on iOS 16+; no-op on iOS 15.
    @ViewBuilder
    func kidSheetDetents() -> some View {
        if #available(iOS 16, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }

    /// Applies presentationDragIndicator(.visible) on iOS 16+; no-op on iOS 15.
    @ViewBuilder
    func kidDragIndicator() -> some View {
        if #available(iOS 16, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

// MARK: - Kid Brush Texture Preview

struct KidBrushPreview: View {
    let brush: BrushDescriptor
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let pts = makeWave(in: size)
            let sz: CGFloat = size.height * 0.38
            let scale = brush.isSystem ? 1.0 : Double((0.4 + brush.sizeVariation * 1.2).clamped(to: 0.1...1.6))
            switch brush.baseStyle {
            case .crayon:  drawCrayon(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .marker:  drawMarker(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .chalk:   drawChalk(ctx: ctx, pts: pts, sz: sz, scale: scale)
            case .patternStamp: drawStamps(ctx: ctx, pts: pts, sz: sz)
            }
        }
    }

    private func makeWave(in size: CGSize) -> [CGPoint] {
        (0..<30).map { i in
            let t = CGFloat(i) / 29
            return CGPoint(
                x: 6 + t * (size.width - 12),
                y: size.height / 2 + sin(t * .pi * 2.5) * (size.height * 0.22)
            )
        }
    }

    private func drawCrayon(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        let passes: [(CGFloat, CGFloat, Double)] = [(-1.5,-1.0,0.50),(0,0,0.65),(1.5,1.0,0.45)]
        for (dx, dy, op) in passes {
            var path = Path()
            let shifted = pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            guard let f = shifted.first else { continue }
            path.move(to: f)
            shifted.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(op * scale, 1.0))),
                       style: StrokeStyle(lineWidth: sz * 0.85, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawMarker(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        var path = Path()
        guard let f = pts.first else { return }
        path.move(to: f)
        pts.dropFirst().forEach { path.addLine(to: $0) }
        ctx.stroke(path, with: .color(color.opacity(min(0.72 * scale, 1.0))),
                   style: StrokeStyle(lineWidth: sz * 1.6, lineCap: .round, lineJoin: .round))
    }

    private func drawChalk(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat, scale: Double) {
        let passes: [(CGFloat, CGFloat, Double)] = [(-1.5,-1.0,0.30),(0,0,0.38),(1.2,0.8,0.28)]
        for (dx, dy, op) in passes {
            var path = Path()
            let shifted = pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            guard let f = shifted.first else { continue }
            path.move(to: f)
            shifted.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: .color(color.opacity(min(op * scale, 1.0))),
                       style: StrokeStyle(lineWidth: sz * 0.65, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawStamps(ctx: GraphicsContext, pts: [CGPoint], sz: CGFloat) {
        let shape = brush.patternShape ?? .star
        let spacing = brush.stampSpacing * sz
        var last: CGPoint? = nil
        for pt in pts {
            if let l = last, hypot(pt.x - l.x, pt.y - l.y) < spacing { continue }
            last = pt
            ctx.fill(shape.path(center: pt, size: sz), with: .color(color))
        }
    }
}

#Preview {
    KidContentView()
}
