import SwiftUI

// MARK: - Kid Crayon Box (20 crayons in classic open box)

struct KidCrayonBoxView: View {
    @ObservedObject var state: DrawingState

    private let boxGreen = Color(r: 28, g: 107, b: 60)
    private let boxGreenLight = Color(r: 40, g: 140, b: 75)
    private let row1 = Array(CrayolaColor.palette.prefix(10))
    private let row2 = Array(CrayolaColor.palette.suffix(10))

    var body: some View {
        VStack(spacing: 0) {
            // ── Lid flap ──
            ZStack {
                CrayonBoxLidShape()
                    .fill(
                        LinearGradient(
                            colors: [boxGreenLight, boxGreen],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 22)
                Text("CRAYONS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: -1)
            }
            .padding(.horizontal, 20)

            // ── Box body ──
            VStack(spacing: 2) {
                // Row 1
                HStack(spacing: 3) {
                    ForEach(row1) { crayola in
                        CrayonTipView(
                            crayola: crayola,
                            isSelected: state.selectedColor == crayola.color,
                            onTap: {
                                state.selectedColor = crayola.color
                                state.isStampMode  = false
                                state.isEraserMode = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)

                // Divider between rows
                Rectangle()
                    .fill(boxGreen.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                // Row 2
                HStack(spacing: 3) {
                    ForEach(row2) { crayola in
                        CrayonTipView(
                            crayola: crayola,
                            isSelected: state.selectedColor == crayola.color,
                            onTap: {
                                state.selectedColor = crayola.color
                                state.isStampMode  = false
                                state.isEraserMode = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(r: 245, g: 240, b: 220))  // cardboard/box interior
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(boxGreen, lineWidth: 2.5)
            )
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
    }
}

// Crayon tip shape: pointed top, rectangular body
struct CrayonTipView: View {
    let crayola: CrayolaColor
    let isSelected: Bool
    let onTap: () -> Void

    @State private var bouncing = false

    private var isLightColor: Bool {
        crayola.name == "White" || crayola.name == "Yellow" || crayola.name == "Peach"
    }

    var body: some View {
        Button(action: {
            onTap()
            bouncing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { bouncing = false }
        }) {
            VStack(spacing: 0) {
                // Pointed tip (triangle)
                CrayonTipShape()
                    .fill(crayola.color)
                    .frame(height: 10)
                    .overlay(
                        CrayonTipShape()
                            .fill(Color.white.opacity(0.25))
                            .mask(
                                // Highlight on left side of tip
                                HStack { Rectangle().frame(width: 4); Spacer() }
                            )
                    )

                // Body (rectangle)
                RoundedRectangle(cornerRadius: 2)
                    .fill(crayola.color)
                    .frame(height: 22)
                    .overlay(
                        // Wrapper label band (darker stripe)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 6)
                            .padding(.horizontal, 1)
                            .offset(y: 2)
                    )
                    .overlay(
                        // Light edge highlight
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1.5)
                            Spacer()
                            Rectangle().fill(Color.black.opacity(0.1)).frame(width: 1)
                        }
                    )
            }
            .overlay(
                // Border for light colors
                Group {
                    if isLightColor {
                        VStack(spacing: 0) {
                            CrayonTipShape()
                                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 0.5)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 0.5)
                                .frame(height: 22)
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .offset(y: isSelected ? -8 : 0)
        .shadow(
            color: isSelected ? crayola.color.opacity(0.6) : .clear,
            radius: isSelected ? 6 : 0,
            x: 0, y: isSelected ? -2 : 0
        )
        .overlay(
            // Selection glow ring
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white, lineWidth: 2)
                        .offset(y: -8)
                }
            }
        )
        .scaleEffect(bouncing ? 1.15 : (isSelected ? 1.08 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: bouncing)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}

// Triangle shape for the crayon tip
struct CrayonTipShape: Shape, InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = insetAmount
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CrayonTipShape {
        CrayonTipShape(insetAmount: insetAmount + amount)
    }
}

// Lid flap shape (wider at bottom, slightly narrower at top with rounded corners)
struct CrayonBoxLidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 6
        path.move(to: CGPoint(x: inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: inset + 4, y: rect.minY + 6))
        path.addQuadCurve(to: CGPoint(x: inset + 10, y: rect.minY),
                          control: CGPoint(x: inset + 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset - 10, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - inset - 4, y: rect.minY + 6),
                          control: CGPoint(x: rect.maxX - inset - 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Color Palette (bottom strip, 20 Crayola swatches)

struct ColorPaletteView: View {
    @ObservedObject var state: DrawingState

    var body: some View {
        HStack(spacing: 8) {
            // Custom color well — always pinned left, never scrolls off screen
            ColorPicker("", selection: Binding(
                get: { state.selectedColor },
                set: { newColor in
                    state.selectedColor = newColor
                    state.isEraserMode  = false
                    state.isStampMode   = false
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 36, height: 36)
            .padding(.horizontal, 4)

            // 20 preset swatches — scroll horizontally so portrait never clips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CrayolaColor.palette) { crayola in
                        ColorSwatchButton(
                            crayola: crayola,
                            isSelected: state.selectedColor == crayola.color,
                            onTap: {
                                state.selectedColor = crayola.color
                                state.isStampMode  = false
                                state.isEraserMode = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: -2)
        )
    }
}

struct ColorSwatchButton: View {
    let crayola: CrayolaColor
    let isSelected: Bool
    let onTap: () -> Void

    @State private var bouncing = false

    var body: some View {
        Button(action: {
            onTap()
            bouncing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bouncing = false }
        }) {
            ZStack {
                Circle()
                    .fill(crayola.color)
                    .frame(width: isSelected ? 52 : 44, height: isSelected ? 52 : 44)
                    .shadow(color: crayola.color.opacity(0.5), radius: isSelected ? 8 : 3, x: 0, y: 2)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 52, height: 52)
                    Circle()
                        .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                        .frame(width: 58, height: 58)
                }

                // White border for light colors
                if crayola.name == "White" || crayola.name == "Yellow" {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: isSelected ? 52 : 44, height: isSelected ? 52 : 44)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(bouncing ? 1.25 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bouncing)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}
