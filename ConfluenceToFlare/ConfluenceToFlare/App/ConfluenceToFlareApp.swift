import SwiftUI

@main
struct ConfluenceToFlareApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 800, height: 700)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
