import SwiftUI

@main
struct ColoringFunApp: App {
    var body: some Scene {
        WindowGroup {
            HubView()
                .preferredColorScheme(.light)
        }
    }
}
