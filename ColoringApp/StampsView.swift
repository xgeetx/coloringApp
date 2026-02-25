import SwiftUI

// MARK: - Stamps Flyout Content

struct StampsFlyoutView: View {
    @ObservedObject var state: DrawingState
    let onDismiss: () -> Void
    var isKidMode: Bool = false
    @State private var selectedCategoryIndex = 0

    // Pastel colours per category for kid mode tabs
    private let kidCategoryColors: [Color] = [
        Color(r: 255, g: 180, b: 100),  // Animals — orange
        Color(r: 130, g: 200, b: 130),  // Insects — green
        Color(r: 255, g: 160, b: 190),  // Plants  — pink
        Color(r: 190, g: 160, b: 230),  // Fun     — purple
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("Stamps")
                .font(.system(size: isKidMode ? 18 : 14, weight: .bold))
                .padding(.top, 6)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isKidMode ? 10 : 6) {
                    ForEach(Array(allStampCategories.enumerated()), id: \.offset) { idx, cat in
                        Button(action: { selectedCategoryIndex = idx }) {
                            if isKidMode {
                                HStack(spacing: 4) {
                                    Text(cat.icon).font(.system(size: 22))
                                    Text(cat.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(selectedCategoryIndex == idx ? .white : .primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategoryIndex == idx
                                              ? kidCategoryColors[min(idx, kidCategoryColors.count - 1)]
                                              : Color.gray.opacity(0.12))
                                )
                            } else {
                                Text(cat.icon)
                                    .font(.system(size: 22))
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(selectedCategoryIndex == idx
                                                  ? Color.accentColor
                                                  : Color.gray.opacity(0.15))
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // Stamp grid
            let category = allStampCategories[selectedCategoryIndex]
            let columns: [GridItem] = isKidMode
                ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(category.stamps, id: \.self) { emoji in
                        StampButton(
                            emoji: emoji,
                            isSelected: state.selectedStamp == emoji && state.isStampMode,
                            fontSize: isKidMode ? 48 : 32,
                            onTap: {
                                state.selectedStamp = emoji
                                state.isStampMode = true
                                if isKidMode {
                                    // Play fun sound in kid mode
                                    StampSynth.shared.speak(stampSoundMap[emoji] ?? emoji)
                                }
                                onDismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .onChange(of: selectedCategoryIndex) { newIndex in
            let category = allStampCategories[newIndex]
            if let first = category.stamps.first {
                state.selectedStamp = first
                state.isStampMode = true
            }
        }
    }
}

struct StampButton: View {
    let emoji: String
    let isSelected: Bool
    var fontSize: CGFloat = 32
    let onTap: () -> Void

    @State private var popped = false

    var body: some View {
        Button(action: {
            onTap()
            popped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { popped = false }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Text(emoji)
                    .font(.system(size: fontSize))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(popped ? 1.3 : (isSelected ? 1.08 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: popped)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}
