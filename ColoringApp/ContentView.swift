import SwiftUI

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var state = DrawingState()

    var body: some View {
        ZStack {
            // Cheerful app chrome gradient
            LinearGradient(
                colors: [
                    Color(r: 255, g: 200, b: 220),
                    Color(r: 255, g: 230, b: 180),
                    Color(r: 200, g: 230, b: 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {

                // ── Top Toolbar ──
                TopToolbarView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // ── Main row: Tools | Canvas | Stamps ──
                HStack(alignment: .top, spacing: 10) {

                    // Left: brush tools
                    BrushToolsView(state: state)
                        .frame(width: 100)

                    // Center: drawing canvas
                    ZStack {
                        DrawingCanvasView(state: state)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)

                        // Stamp mode indicator banner
                        if state.isStampMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    Label("Tap to stamp  \(state.selectedStamp)", systemImage: "hand.tap.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(Color.purple.opacity(0.85))
                                        )
                                    Spacer()
                                }
                                .padding(.top, 12)
                                Spacer()
                            }
                        }
                    }

                    // Right: stamps
                    StampsPanelView(state: state)
                        .frame(width: 120)
                }
                .padding(.horizontal, 12)

                // ── Bottom: color palette ──
                ColorPaletteView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }
}

#Preview {
    ContentView()
}
