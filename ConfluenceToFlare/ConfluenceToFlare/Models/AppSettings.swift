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
        // Try UserDefaults first (previously saved settings)
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data),
           settings.isValid {
            return settings
        }
        // Fall back to config.yaml next to the executable or in the project root
        if let yamlSettings = loadFromConfigYaml() {
            return yamlSettings
        }
        return AppSettings()
    }

    /// Load settings from config.yaml (shared with the Python web app).
    private static func loadFromConfigYaml() -> AppSettings? {
        // Search for config.yaml in likely locations
        let candidates = [
            // Next to the executable's working directory
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("config.yaml"),
            // In the mac_confluence_to_flare project root
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/Claude Code Projects/mac_confluence_to_flare/config.yaml"),
        ]

        for candidate in candidates {
            guard let content = try? String(contentsOf: candidate, encoding: .utf8) else { continue }

            // Simple YAML key-value parser (no dependency needed for our flat config)
            var settings = AppSettings()
            var apiToken: String?

            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), trimmed.contains(":") else { continue }

                let parts = trimmed.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                switch key {
                case "base_url": settings.confluenceBaseURL = value
                case "email": settings.confluenceEmail = value
                case "api_token": apiToken = value
                case "production_parent_id": settings.productionParentID = value
                case "root":
                    if !value.isEmpty { settings.flareProjectRoot = value }
                case "release_notes_dir": settings.releaseNotesDir = value
                case "images_dir": settings.imagesDir = value
                case "overview_file": settings.overviewFile = value
                case "toc_file": settings.tocFile = value
                default: break
                }
            }

            guard settings.isValid else { continue }

            // Store the API token in Keychain so createConfluenceClient() can find it
            if let token = apiToken, !token.isEmpty {
                KeychainService.save(token: token, account: settings.confluenceEmail)
            }

            // Persist to UserDefaults so future launches don't need config.yaml
            settings.save()

            return settings
        }
        return nil
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppSettings.userDefaultsKey)
        }
    }
}
