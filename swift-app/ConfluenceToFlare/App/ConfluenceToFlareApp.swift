import SwiftUI

@main
struct ConfluenceToFlareApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
                .background(WindowFrameSaver())
        }
        .defaultSize(width: 1100, height: 650)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

/// Sets a frameAutosaveName on the hosting NSWindow so macOS persists its position and size.
private struct WindowFrameSaver: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("MainWindow")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
