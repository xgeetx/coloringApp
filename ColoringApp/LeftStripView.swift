import SwiftUI

// MARK: - Left Icon Strip

struct LeftStripView: View {
    @ObservedObject var state: DrawingState
    @Binding var activeFlyout: FlyoutPanel?

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 4)

            StripIconButton(
                systemImage: "paintbrush.fill",
                label: "Brush",
                isActive: activeFlyout == .brushes
            ) {
                activeFlyout = activeFlyout == .brushes ? nil : .brushes
            }

            StripIconButton(
                systemImage: "lineweight",
                label: "Size",
                isActive: activeFlyout == .size
            ) {
                activeFlyout = activeFlyout == .size ? nil : .size
            }

            StripIconButton(
                systemImage: "circle.lefthalf.filled",
                label: "Opacity",
                isActive: activeFlyout == .opacity
            ) {
                activeFlyout = activeFlyout == .opacity ? nil : .opacity
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: 44)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 2, y: 2)
        )
    }
}

// MARK: - Strip Icon Button (shared)

struct StripIconButton: View {
    let systemImage: String
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .frame(width: 40, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isActive)
    }
}
