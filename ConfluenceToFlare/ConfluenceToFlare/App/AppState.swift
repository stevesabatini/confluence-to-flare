import Foundation
import Observation

@Observable
final class AppState {
    var settings = AppSettings.load()
    var isSettingsValid: Bool {
        settings.isValid
    }

    func createConfluenceClient() -> ConfluenceClient? {
        guard let token = KeychainService.load(account: settings.confluenceEmail) else {
            return nil
        }
        return ConfluenceClient(
            baseURL: settings.confluenceBaseURL,
            email: settings.confluenceEmail,
            apiToken: token
        )
    }
}
