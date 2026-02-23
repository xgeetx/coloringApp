import SwiftUI

// MARK: - Brush Builder (fullScreenCover)

struct BrushBuilderView: View {
    @ObservedObject var state: DrawingState
    @Environment(\.dismiss) var dismiss

    @State private var selectedStyle: BrushBaseStyle = .patternStamp
    @State private var selectedShape: PatternShape   = .heart
    @State private var stampSpacing: CGFloat         = 1.2
    @State private var sizeVariation: CGFloat        = 0.2
    @State private var brushName: String             = "My Hearts"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    styleSection
                    if selectedStyle == .patternStamp { shapeSection }
                    sliderSection
                    nameSection
                    saveButton
                }
                .padding(24)
            }
            .navigationTitle("Build Your Brush")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("STYLE")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(BrushBaseStyle.allCases, id: \.rawValue) { style in
                    StyleTile(
                        icon: style.icon,
                        label: style == .patternStamp ? "Pattern" : style.rawValue.capitalized,
                        isSelected: selectedStyle == style
                    ) {
                        selectedStyle = style
                        updateName()
                    }
                }
            }
        }
    }

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SHAPE")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(PatternShape.allCases, id: \.rawValue) { shape in
                    ShapeTile(shape: shape, isSelected: selectedShape == shape) {
                        selectedShape = shape
                        updateName()
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: selectedStyle)
    }

    private var sliderSection: some View {
        VStack(spacing: 20) {
            LabeledBuilderSlider(label: "SPACING",  value: $stampSpacing,  range: 0.5...3.0,
                                 leftNote: "dense", rightNote: "sparse")
            LabeledBuilderSlider(label: "SIZE MIX", value: $sizeVariation, range: 0.0...1.0,
                                 leftNote: "uniform", rightNote: "wild")
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NAME")
            TextField("Brush Name", text: $brushName)
                .font(.system(size: 22))
                .frame(height: 60)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.1))
                )
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("💾  Save Brush")
                .font(.system(size: 24, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.accentColor))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func updateName() {
        if selectedStyle == .patternStamp {
            brushName = "My \(selectedShape.displayName)s"
        } else {
            brushName = "My \(selectedStyle.rawValue.capitalized)"
        }
    }

    private func save() {
        let icon: String = selectedStyle == .patternStamp ? selectedShape.icon : selectedStyle.icon
        let descriptor = BrushDescriptor(
            id: UUID(),
            name: brushName.isEmpty ? "My Brush" : brushName,
            icon: icon,
            baseStyle: selectedStyle,
            patternShape: selectedStyle == .patternStamp ? selectedShape : nil,
            stampSpacing: stampSpacing,
            sizeVariation: sizeVariation,
            isSystem: false
        )
        state.addBrush(descriptor)
        dismiss()
    }
}

// MARK: - StyleTile

struct StyleTile: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(icon).font(.system(size: 48))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - ShapeTile

struct ShapeTile: View {
    let shape: PatternShape
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(shape.icon).font(.system(size: 36))
                Text(shape.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - LabeledBuilderSlider

struct LabeledBuilderSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let leftNote: String
    let rightNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range)
                .controlSize(.large)
            HStack {
                Text(leftNote).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Text(rightNote).font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
