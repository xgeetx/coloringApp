import SwiftUI

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var state = DrawingState()
    @State private var activeFlyout: FlyoutPanel? = nil

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

                // ── Main row: Left Strip | Canvas | Right Strip ──
                HStack(alignment: .top, spacing: 8) {

                    // Left icon strip
                    LeftStripView(state: state, activeFlyout: $activeFlyout)

                    // Center: canvas + flyout overlays
                    ZStack {
                        // Drawing canvas
                        DrawingCanvasView(state: state, dismissFlyout: {
                            withAnimation(.easeIn(duration: 0.2)) {
                                activeFlyout = nil
                            }
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                        // Left flyout overlay (.brushes / .size / .opacity)
                        if let panel = activeFlyout, panel != .stamps {
                            FlyoutContainerView(side: .left, onDismiss: {
                                withAnimation(.easeIn(duration: 0.2)) { activeFlyout = nil }
                            }) {
                                leftFlyoutContent(panel)
                            }
                            .frame(width: 260)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .transition(.move(edge: .leading))
                        }

                        // Right flyout overlay (.stamps)
                        if activeFlyout == .stamps {
                            FlyoutContainerView(side: .right, onDismiss: {
                                withAnimation(.easeIn(duration: 0.2)) { activeFlyout = nil }
                            }) {
                                StampsFlyoutView(state: state, onDismiss: {
                                    withAnimation(.easeIn(duration: 0.2)) { activeFlyout = nil }
                                })
                            }
                            .frame(width: 260)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .transition(.move(edge: .trailing))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeFlyout)

                    // Right icon strip
                    RightStripView(state: state, activeFlyout: $activeFlyout)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)

                // ── Bottom: color palette ──
                ColorPaletteView(state: state)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Left Flyout Content Switch

    @ViewBuilder
    private func leftFlyoutContent(_ panel: FlyoutPanel) -> some View {
        switch panel {
        case .brushes:
            BrushesFlyoutView(state: state)
        case .size:
            SizeFlyoutView(state: state)
        case .opacity:
            OpacityFlyoutView(state: state)
        case .stamps:
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
