import SwiftUI

// MARK: - Right Icon Strip

struct RightStripView: View {
    @ObservedObject var state: DrawingState
    @Binding var activeFlyout: FlyoutPanel?

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 4)

            StripIconButton(
                systemImage: "seal.fill",
                label: "Stamps",
                isActive: activeFlyout == .stamps
            ) {
                activeFlyout = activeFlyout == .stamps ? nil : .stamps
                if activeFlyout == .stamps {
                    state.isStampMode = true
                }
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
