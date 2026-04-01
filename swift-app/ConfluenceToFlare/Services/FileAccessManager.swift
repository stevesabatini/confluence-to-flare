import Foundation
import AppKit

/// Manages security-scoped bookmark access for the Flare project directory.
///
/// Under macOS sandbox, the app needs user permission (via NSOpenPanel)
/// to access the Flare project directory. This manager persists that
/// permission as a security-scoped bookmark so it survives app restarts.
struct FileAccessManager {
    private static let bookmarkKey = "flareProjectBookmark"

    /// Present an NSOpenPanel to let the user select the Flare project root directory.
    ///
    /// - Returns: The selected directory URL, or nil if the user cancelled.
    @MainActor
    static func requestAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select Flare Project Root"
        panel.message = "Choose the root folder of your MadCap Flare project"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        saveBookmark(for: url)
        return url
    }

    /// Save a security-scoped bookmark for the given URL.
    static func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            // Silently fail — the user will be prompted again next launch
        }
    }

    /// Restore access from a saved security-scoped bookmark.
    ///
    /// - Returns: The resolved URL if the bookmark is valid, or nil.
    static func restoreAccess() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Re-save the bookmark
                saveBookmark(for: url)
            }

            return url
        } catch {
            return nil
        }
    }

    /// Start accessing a security-scoped resource.
    /// Must be balanced with `stopAccess(_:)`.
    static func startAccess(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    /// Stop accessing a security-scoped resource.
    static func stopAccess(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
