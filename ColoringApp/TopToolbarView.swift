import SwiftUI

// MARK: - Top Toolbar

struct TopToolbarView: View {
    @ObservedObject var state: DrawingState
    @State private var showBgColorPicker = false
    @State private var showClearConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 14) {
            // Home
            ToolbarButton(
                icon: "house.fill",
                label: "Home",
                color: .indigo,
                disabled: false,
                action: { dismiss() }
            )

            // App title
            HStack(spacing: 6) {
                Text("🎨")
                    .font(.system(size: 28))
                Text("Coloring Fun!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Spacer()

            // Background color picker
            Button {
                showBgColorPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.fill")
                        .foregroundStyle(state.backgroundColor)
                        .font(.system(size: 18))
                        .shadow(color: .black.opacity(0.2), radius: 1)
                    Text("Background")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 3)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showBgColorPicker) {
                BackgroundColorPickerView(state: state)
            }

            // Undo
            ToolbarButton(
                icon: "arrow.uturn.backward",
                label: "Undo",
                color: .blue,
                disabled: !state.canUndo,
                action: { state.undo() }
            )

            // Clear
            ToolbarButton(
                icon: "trash",
                label: "Clear",
                color: .red,
                disabled: false,
                action: { showClearConfirm = true }
            )
            .confirmationDialog("Clear the whole drawing?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear It! 🗑️", role: .destructive) { state.clear() }
                Button("Keep It! 🎨", role: .cancel) {}
            }

            // Eraser
            ToolbarButton(
                icon: "eraser.fill",
                label: "Eraser",
                color: .orange,
                disabled: false,
                action: {
                    state.isEraserMode.toggle()
                    if state.isEraserMode { state.isStampMode = false }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(state.isEraserMode ? Color.orange : Color.clear, lineWidth: 2)
            )
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

struct ToolbarButton: View {
    let icon: String
    let label: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            action()
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(disabled ? .gray : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(disabled ? Color.gray.opacity(0.08) : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Background Color Picker Popover

struct BackgroundColorPickerView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    private let bgColors: [(String, Color)] = [
        // Neutrals
        ("Cream",      Color(r: 255, g: 250, b: 235)),
        ("White",      Color(r: 255, g: 255, b: 255)),
        ("Pearl",      Color(r: 240, g: 235, b: 220)),
        // Pastels
        ("Sky",        Color(r: 204, g: 229, b: 255)),
        ("Mint",       Color(r: 204, g: 255, b: 229)),
        ("Peach",      Color(r: 255, g: 220, b: 200)),
        ("Lavender",   Color(r: 230, g: 210, b: 255)),
        ("Lemon",      Color(r: 255, g: 255, b: 200)),
        ("Rose",       Color(r: 255, g: 210, b: 220)),
        ("Baby Blue",  Color(r: 180, g: 220, b: 255)),
        ("Honeydew",   Color(r: 210, g: 255, b: 210)),
        ("Blush",      Color(r: 255, g: 200, b: 210)),
        // Brights
        ("Sunny",      Color(r: 255, g: 240, b: 100)),
        ("Coral",      Color(r: 255, g: 160, b: 130)),
        ("Aqua",       Color(r: 130, g: 220, b: 220)),
        ("Lilac",      Color(r: 200, g: 170, b: 255)),
        // Darks
        ("Slate",      Color(r: 80,  g: 100, b: 130)),
        ("Forest",     Color(r: 40,  g: 80,  b: 60)),
        ("Midnight",   Color(r: 20,  g: 25,  b: 60)),
        ("Charcoal",   Color(r: 55,  g: 55,  b: 65)),
        ("Black",      Color(r: 20,  g: 20,  b: 20)),
        // Warm darks
        ("Mocha",      Color(r: 80,  g: 50,  b: 30)),
        ("Burgundy",   Color(r: 90,  g: 20,  b: 40)),
        ("Dark Teal",  Color(r: 20,  g: 80,  b: 80)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick Background")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.top, 16)
                .padding(.horizontal, 16)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(bgColors, id: \.0) { name, color in
                        Button {
                            state.backgroundColor = color
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().strokeBorder(
                                            state.backgroundColor == color ? Color.accentColor : Color.gray.opacity(0.3),
                                            lineWidth: state.backgroundColor == color ? 3 : 1
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 3)
                                Text(name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Custom color picker as final grid item
                    VStack(spacing: 4) {
                        ColorPicker("", selection: $state.backgroundColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 48, height: 48)
                        Text("Custom")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 340, height: 420)
    }
}
