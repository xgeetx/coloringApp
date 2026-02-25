import SwiftUI

// MARK: - Kid Mode Root View

struct KidContentView: View {
    @StateObject private var state = DrawingState()
    @State private var showMoreStamps  = false
    @State private var showKidBuilder  = false

    private var systemTextureBrushes: [BrushDescriptor] {
        let textureStyles: Set<BrushBaseStyle> = [.crayon, .marker, .chalk]
        return BrushDescriptor.systemBrushes.filter {
            textureStyles.contains($0.baseStyle) || $0.name == "Sparkle"
        }
    }

    private var kidUserBrushes: [BrushDescriptor] {
        state.brushPool.filter { !$0.isSystem }
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
                        systemBrushes: systemTextureBrushes,
                        userBrushes: kidUserBrushes,
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

            if !state.isStampMode && !state.isEraserMode {
                HStack(spacing: 20) {
                    KidSlider(label: "Size",
                              value: $state.brushSize,
                              range: 6...80,
                              color: .blue)
                    KidSlider(label: "Opacity",
                              value: $state.brushOpacity,
                              range: 0.2...1.0,
                              color: .purple)
                }
                .padding(.horizontal, 12)
            } else {
                Spacer()
            }

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

struct KidSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Slider(value: $value, in: range)
                .tint(color)
        }
        .frame(maxWidth: 150)
    }
}

// MARK: - Kid Brush Strip (left panel)

struct KidBrushStripView: View {
    @ObservedObject var state: DrawingState
    let systemBrushes: [BrushDescriptor]
    let userBrushes: [BrushDescriptor]    // max 2; capped at save time
    let onBuildBrush: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                // ── System brushes ──
                ForEach(systemBrushes) { brush in
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

                // ── My Brushes: bordered box containing user brushes + Make ──
                VStack(spacing: 8) {
                    ForEach(userBrushes) { brush in
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

                    Button(action: onBuildBrush) {
                        VStack(spacing: 4) {
                            Text("🔮")
                                .font(.system(size: 26))
                            Text("Make")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.purple.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.purple.opacity(0.35),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        )
                )

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
            let seed = brush.id.hashValue & 0x7FFF_FFFF
            let w = size.width, h = size.height
            if brush.isSystem {
                switch brush.baseStyle {
                case .crayon:       drawCrayon(ctx: ctx, w: w, h: h, seed: seed)
                case .marker:       drawMarker(ctx: ctx, w: w, h: h)
                case .chalk:        drawChalk(ctx: ctx, w: w, h: h, seed: seed)
                case .patternStamp: drawSparkle(ctx: ctx, w: w, h: h, seed: seed)
                }
            } else {
                drawSplatter(ctx: ctx, w: w, h: h, seed: seed)
            }
        }
    }

    // Deterministic value in [0, 1) — same hash as DrawingCanvasView.deterministicJitter
    private func rng(_ seed: Int, _ i: Int) -> CGFloat {
        let h = (seed ^ (i &* 2654435761)) & 0x7FFF_FFFF
        return CGFloat(h % 10000) / 10000.0
    }

    // ── Crayon: diagonal band, 5 layered passes + paper-grain stipple ──
    private func drawCrayon(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let lw: CGFloat = min(w, h) * 0.38
        let start = CGPoint(x: 6, y: h - 6)
        let end   = CGPoint(x: w - 6, y: 6)
        let passes: [(CGFloat, CGFloat, Double)] = [
            (-4, -2, 0.38), (-2, -1, 0.55), (0, 0, 0.70), (2, 1, 0.52), (4, 2, 0.35)
        ]
        for (dx, dy, op) in passes {
            var path = Path()
            path.move(to: CGPoint(x: start.x + dx, y: start.y + dy))
            path.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy))
            ctx.stroke(path, with: .color(color.opacity(op)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        // Grain stipple — dots scattered along the diagonal band
        let ddx = end.x - start.x, ddy = end.y - start.y
        for i in 0..<80 {
            let t    = rng(seed, i * 4)
            let perp = rng(seed, i * 4 + 1) * 2 - 1
            let dotR = 0.4 + rng(seed, i * 4 + 2) * 1.4
            let op   = 0.05 + rng(seed, i * 4 + 3) * 0.20
            let x    = start.x + t * ddx + perp * lw * 0.5
            let y    = start.y + t * ddy + perp * lw * 0.3
            ctx.fill(Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                               width: dotR * 2, height: dotR * 2)),
                     with: .color(color.opacity(op)))
        }
    }

    // ── Marker: clean horizontal stroke + soft ink-bleed halo ──
    private func drawMarker(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let lw: CGFloat = min(w, h) * 0.46
        let y = h / 2
        // Halo first (wider, very faint — ink bleed)
        var haloPath = Path()
        haloPath.move(to: CGPoint(x: 6, y: y))
        haloPath.addLine(to: CGPoint(x: w - 6, y: y))
        ctx.stroke(haloPath, with: .color(color.opacity(0.10)),
                   style: StrokeStyle(lineWidth: lw * 1.5, lineCap: .round))
        // Solid stroke on top
        var path = Path()
        path.move(to: CGPoint(x: 6, y: y))
        path.addLine(to: CGPoint(x: w - 6, y: y))
        ctx.stroke(path, with: .color(color.opacity(0.88)),
                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // ── Chalk: 3 faint diagonal strokes + scattered dust dots ──
    private func drawChalk(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let lw: CGFloat = min(w, h) * 0.22
        let start = CGPoint(x: 6, y: h - 6)
        let end   = CGPoint(x: w - 6, y: 6)
        let passes: [(CGFloat, CGFloat, Double)] = [(-3, -2, 0.20), (0, 0, 0.26), (3, 2, 0.18)]
        for (dx, dy, op) in passes {
            var path = Path()
            path.move(to: CGPoint(x: start.x + dx, y: start.y + dy))
            path.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy))
            ctx.stroke(path, with: .color(color.opacity(op)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        // Chalk dust: micro-dots with wider spread than crayon grain
        let ddx = end.x - start.x, ddy = end.y - start.y
        for i in 0..<55 {
            let t    = rng(seed, i * 4)
            let perp = rng(seed, i * 4 + 1) * 2 - 1
            let dotR = 0.2 + rng(seed, i * 4 + 2) * 0.9
            let op   = 0.03 + rng(seed, i * 4 + 3) * 0.10
            let x    = start.x + t * ddx + perp * lw * 1.8
            let y    = start.y + t * ddy + perp * lw * 1.2
            ctx.fill(Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                               width: dotR * 2, height: dotR * 2)),
                     with: .color(color.opacity(op)))
        }
    }

    // ── Sparkle: scattered stars, no stroke ──
    private func drawSparkle(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        for i in 0..<6 {
            let x  = 8 + rng(seed, i * 3)     * (w - 16)
            let y  = 8 + rng(seed, i * 3 + 1) * (h - 16)
            let sz = 6 + rng(seed, i * 3 + 2) * 10
            ctx.fill(PatternShape.star.path(center: CGPoint(x: x, y: y), size: sz),
                     with: .color(color))
        }
    }

    // ── Splatter: seeded dot cloud for user-created brushes ──
    private func drawSplatter(ctx: GraphicsContext, w: CGFloat, h: CGFloat, seed: Int) {
        let cx = w / 2, cy = h / 2
        let maxR = min(w, h) * 0.44
        for i in 0..<30 {
            let angle  = rng(seed, i * 4)     * .pi * 2
            let radius = 2 + rng(seed, i * 4 + 1) * maxR
            let dotR   = 1 + rng(seed, i * 4 + 2) * 4.5
            let op     = 0.30 + rng(seed, i * 4 + 3) * 0.60
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            ctx.fill(
                Ellipse().path(in: CGRect(x: x - dotR, y: y - dotR,
                                          width: dotR * 2, height: dotR * 2)),
                with: .color(color.opacity(op))
            )
        }
    }
}

#Preview {
    KidContentView()
}
