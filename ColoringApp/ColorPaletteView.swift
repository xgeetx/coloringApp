import SwiftUI

// MARK: - Color Palette (bottom strip, 16 Crayola swatches)

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

            // 16 preset swatches — scroll horizontally so portrait never clips
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
