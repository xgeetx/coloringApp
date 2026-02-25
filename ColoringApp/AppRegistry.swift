import SwiftUI

// MARK: - App Descriptor

struct MiniAppDescriptor: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let icon: String          // emoji
    let tileColor: Color
    let isAvailable: Bool
    let makeRootView: () -> AnyView

    static func placeholder(id: String, icon: String, displayName: String) -> MiniAppDescriptor {
        MiniAppDescriptor(
            id: id,
            displayName: displayName,
            subtitle: "Coming Soon",
            icon: icon,
            tileColor: Color(r: 210, g: 210, b: 230),
            isAvailable: false,
            makeRootView: { AnyView(EmptyView()) }
        )
    }
}

extension MiniAppDescriptor: Equatable {
    static func == (lhs: MiniAppDescriptor, rhs: MiniAppDescriptor) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Registry

enum AppRegistry {
    static let apps: [MiniAppDescriptor] = [
        MiniAppDescriptor(
            id: "coloring",
            displayName: "Coloring Fun",
            subtitle: "Draw & Stamp!",
            icon: "🎨",
            tileColor: Color(r: 255, g: 150, b: 180),
            isAvailable: true,
            makeRootView: { AnyView(ContentView()) }
        ),
        MiniAppDescriptor(
            id: "kidsmode",
            displayName: "Kids Mode",
            subtitle: "Paint & Play!",
            icon: "🌈",
            tileColor: Color(r: 180, g: 230, b: 255),
            isAvailable: true,
            makeRootView: { AnyView(KidContentView()) }
        ),
        .placeholder(id: "app3", icon: "🧩", displayName: "Puzzle Play"),
        .placeholder(id: "app4", icon: "📖", displayName: "Story Time"),
    ]
}
