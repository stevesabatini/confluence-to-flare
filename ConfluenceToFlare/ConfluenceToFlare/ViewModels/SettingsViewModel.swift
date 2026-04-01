import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var baseURL: String = ""
    var email: String = ""
    var apiToken: String = ""
    var parentPageID: String = ""
    var flareProjectRoot: String = ""
    var releaseNotesDir: String = "Content/E_Landing Topics/Release Notes"
    var imagesDir: String = "Content/Resources/From Confluence/Release Notes"
    var overviewFile: String = "Content/E_Landing Topics/Release Notes/Release Notes Overview.htm"
    var tocFile: String = "Project/TOCs/Landing Topic Mini TOCs/Visualization Guide Mini-TOC.fltoc"

    var showAdvancedPaths: Bool = false
    var showToken: Bool = false
    var testConnectionStatus: String = ""
    var isTesting: Bool = false
    var isSaved: Bool = false

    init() {
        loadFromSettings()
    }

    func loadFromSettings() {
        let settings = AppSettings.load()
        baseURL = settings.confluenceBaseURL
        email = settings.confluenceEmail
        parentPageID = settings.productionParentID
        flareProjectRoot = settings.flareProjectRoot
        releaseNotesDir = settings.releaseNotesDir
        imagesDir = settings.imagesDir
        overviewFile = settings.overviewFile
        tocFile = settings.tocFile

        // Load token from Keychain
        if !email.isEmpty {
            apiToken = KeychainService.load(account: email) ?? ""
        }
    }

    func save() {
        var settings = AppSettings()
        settings.confluenceBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.confluenceEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.productionParentID = parentPageID.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.flareProjectRoot = flareProjectRoot
        settings.releaseNotesDir = releaseNotesDir
        settings.imagesDir = imagesDir
        settings.overviewFile = overviewFile
        settings.tocFile = tocFile
        settings.save()

        // Save token to Keychain
        if !email.isEmpty && !apiToken.isEmpty {
            KeychainService.save(token: apiToken, account: settings.confluenceEmail)
        }

        isSaved = true

        // Reset saved indicator after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            isSaved = false
        }
    }

    var isValid: Bool {
        !baseURL.isEmpty &&
        !email.isEmpty &&
        !apiToken.isEmpty &&
        !parentPageID.isEmpty &&
        !flareProjectRoot.isEmpty
    }

    @MainActor
    func chooseFlareProject() {
        if let url = FileAccessManager.requestAccess() {
            flareProjectRoot = url.path
        }
    }

    func testConnection() {
        guard isValid else {
            testConnectionStatus = "Please fill in all fields first."
            return
        }

        isTesting = true
        testConnectionStatus = "Testing..."

        Task {
            do {
                let client = ConfluenceClient(
                    baseURL: baseURL,
                    email: email,
                    apiToken: apiToken
                )
                let title = try await client.getPageTitle(pageID: parentPageID)
                await MainActor.run {
                    testConnectionStatus = "Connected! Found page: \(title)"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testConnectionStatus = "Connection failed: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}
