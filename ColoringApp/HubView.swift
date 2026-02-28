import SwiftUI

// MARK: - Hub Screen

struct HubView: View {
    @State private var activeApp: MiniAppDescriptor? = nil
    @State private var requestingApp: MiniAppDescriptor? = nil
    @State private var hubTitle: String = UserDefaults.standard.string(forKey: "hubTitle") ?? "Triple Tap here to change Name"
    @State private var showRenameAlert = false
    @State private var pendingTitle = ""

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        ZStack {
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

            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    Text("🌟")
                        .font(.system(size: 48))
                    Text(hubTitle)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .onTapGesture(count: 3) {
                            pendingTitle = hubTitle == "Triple Tap here to change Name" ? "" : hubTitle
                            showRenameAlert = true
                        }
                }
                .padding(.top, 36)

                // App tiles — first 4 in 2x2 grid
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(Array(AppRegistry.apps.prefix(4))) { app in
                        AppTileView(app: app) {
                            if app.isAvailable {
                                activeApp = app
                            } else {
                                requestingApp = app
                            }
                        }
                    }
                }
                .padding(.horizontal, 48)

                // Overflow row — centered below grid
                if AppRegistry.apps.count > 4 {
                    HStack(spacing: 24) {
                        ForEach(Array(AppRegistry.apps.dropFirst(4))) { app in
                            AppTileView(app: app) {
                                if app.isAvailable {
                                    activeApp = app
                                } else {
                                    requestingApp = app
                                }
                            }
                            .frame(maxWidth: UIScreen.main.bounds.width / 2 - 60)
                        }
                    }
                    .padding(.horizontal, 48)
                }

                Spacer()
            }
        }
        .fullScreenCover(item: $activeApp) { app in
            app.makeRootView()
        }
        .sheet(item: $requestingApp) { app in
            AppRequestView(app: app)
        }
        .alert("Name Your Zone", isPresented: $showRenameAlert) {
            TextField("Enter a name", text: $pendingTitle)
            Button("Save") {
                let trimmed = pendingTitle.trimmingCharacters(in: .whitespaces)
                hubTitle = trimmed.isEmpty ? "Triple Tap here to change Name" : trimmed
                UserDefaults.standard.set(hubTitle, forKey: "hubTitle")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Triple-tap the title any time to change it.")
        }
    }
}

// MARK: - App Tile

struct AppTileView: View {
    let app: MiniAppDescriptor
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                pressed = false
                onTap()
            }
        } label: {
            VStack(spacing: 14) {
                Text(app.icon)
                    .font(.system(size: 72))

                Text(app.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(app.isAvailable ? .white : Color(r: 110, g: 110, b: 130))
                    .multilineTextAlignment(.center)

                Text(app.subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(app.isAvailable ? .white.opacity(0.85) : Color(r: 150, g: 150, b: 170))
                    .multilineTextAlignment(.center)

                if !app.isAvailable {
                    Text("Tap to request!")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.35)))
                        .foregroundStyle(Color(r: 100, g: 100, b: 130))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(app.isAvailable ? app.tileColor : Color(r: 225, g: 225, b: 240))
            )
            .shadow(
                color: app.isAvailable ? app.tileColor.opacity(0.45) : .gray.opacity(0.15),
                radius: app.isAvailable ? 18 : 6,
                x: 0, y: 6
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

#Preview {
    HubView()
}
