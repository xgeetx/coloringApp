import SwiftUI

// MARK: - Flyout Container

/// Generic slide-in panel wrapper used by all flyout panels.
/// Handles background, rounded corners, drop shadow, and X dismiss button.
struct FlyoutContainerView<Content: View>: View {
    enum Side { case left, right }

    let side: Side
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: side == .left ? .topTrailing : .topLeading) {
            // Panel background
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.95))
                .shadow(
                    color: .black.opacity(0.20),
                    radius: 16,
                    x: side == .left ? 10 : -10,
                    y: 0
                )

            // Content (padded away from the X button)
            content()
                .padding(.top, 50)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // X dismiss button — opposite corner from the strip
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}
