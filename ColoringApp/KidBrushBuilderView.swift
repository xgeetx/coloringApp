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
                                let path = selectedShape.path(center: pt, size: brushSize)
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

}
