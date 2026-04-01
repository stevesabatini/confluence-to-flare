import Foundation

struct AppSettings: Codable {
    // Confluence connection
    var confluenceBaseURL: String = ""
    var confluenceEmail: String = ""
    var productionParentID: String = ""

    // Flare project paths
    var flareProjectRoot: String = ""
    var releaseNotesDir: String = "Content/E_Landing Topics/Release Notes"
    var imagesDir: String = "Content/Resources/From Confluence/Release Notes"
    var overviewFile: String = "Content/E_Landing Topics/Release Notes/Release Notes Overview.htm"
    var tocFile: String = "Project/TOCs/Landing Topic Mini TOCs/Visualization Guide Mini-TOC.fltoc"

    // Security-scoped bookmark data for the Flare project root
    var flareProjectBookmark: Data?

    var isValid: Bool {
        !confluenceBaseURL.isEmpty &&
        !confluenceEmail.isEmpty &&
        !productionParentID.isEmpty &&
        !flareProjectRoot.isEmpty
    }

    // MARK: - Resolved paths

    var resolvedProjectRoot: URL? {
        guard !flareProjectRoot.isEmpty else { return nil }
        return URL(fileURLWithPath: flareProjectRoot)
    }

    func resolvedReleaseNotesDir() -> URL? {
        resolvedProjectRoot?.appendingPathComponent(releaseNotesDir)
    }

    func resolvedImagesDir() -> URL? {
        resolvedProjectRoot?.appendingPathComponent(imagesDir)
    }

    func resolvedOverviewFile() -> URL? {
        resolvedProjectRoot?.appendingPathComponent(overviewFile)
    }

    func resolvedTocFile() -> URL? {
        resolvedProjectRoot?.appendingPathComponent(tocFile)
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "appSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppSettings.userDefaultsKey)
        }
    }
}
