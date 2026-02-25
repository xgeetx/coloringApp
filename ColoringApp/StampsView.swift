import SwiftUI

// MARK: - Stamps Flyout Content

struct StampsFlyoutView: View {
    @ObservedObject var state: DrawingState
    let onDismiss: () -> Void
    @State private var selectedCategoryIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            Text("Stamps")
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 6)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(allStampCategories.enumerated()), id: \.offset) { idx, cat in
                        Button(action: { selectedCategoryIndex = idx }) {
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // Stamp grid
            let category = allStampCategories[selectedCategoryIndex]
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(category.stamps, id: \.self) { emoji in
                        StampButton(
                            emoji: emoji,
                            isSelected: state.selectedStamp == emoji && state.isStampMode,
                            onTap: {
                                state.selectedStamp = emoji
                                state.isStampMode = true
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
                    .font(.system(size: 32))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(popped ? 1.3 : (isSelected ? 1.08 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: popped)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }
}
