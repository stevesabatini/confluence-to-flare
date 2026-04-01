import Foundation
import Observation

@Observable
final class PageListViewModel {
    var pages: [ConfluencePage] = []
    var selectedPageIDs: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?
    var forceReimport: Bool = false

    var selectedCount: Int {
        selectedPageIDs.count
    }

    var selectablePages: [ConfluencePage] {
        if forceReimport {
            return pages.filter { $0.parsedDate != nil }
        }
        return pages.filter { $0.parsedDate != nil && !$0.isImported }
    }

    var allSelectableSelected: Bool {
        let selectableIDs = Set(selectablePages.map(\.id))
        return !selectableIDs.isEmpty && selectableIDs.isSubset(of: selectedPageIDs)
    }

    func toggleSelectAll() {
        let selectableIDs = Set(selectablePages.map(\.id))
        if allSelectableSelected {
            selectedPageIDs.subtract(selectableIDs)
        } else {
            selectedPageIDs.formUnion(selectableIDs)
        }
    }

    func togglePage(_ page: ConfluencePage) {
        if selectedPageIDs.contains(page.id) {
            selectedPageIDs.remove(page.id)
        } else {
            selectedPageIDs.insert(page.id)
        }
    }

    func isSelected(_ page: ConfluencePage) -> Bool {
        selectedPageIDs.contains(page.id)
    }

    func isSelectable(_ page: ConfluencePage) -> Bool {
        guard page.parsedDate != nil else { return false }
        return forceReimport || !page.isImported
    }

    func loadPages(appState: AppState) {
        guard let client = appState.createConfluenceClient() else {
            errorMessage = "Invalid configuration. Please check Settings."
            return
        }

        isLoading = true
        errorMessage = nil
        selectedPageIDs.removeAll()

        Task {
            do {
                let settings = appState.settings
                let releaseNotesDir = settings.resolvedReleaseNotesDir()
                let importedPageIDs = releaseNotesDir != nil
                    ? ImportEngine.getImportedPageIDs(releaseNotesDir: releaseNotesDir!)
                    : Set<String>()

                let rawPages = try await client.getReleaseFeaturePages(
                    productionParentID: settings.productionParentID
                )

                let confluencePages = rawPages.map { raw in
                    let pageType: ConfluencePage.PageType = raw.type == "patch" ? .patch : .features
                    return ConfluencePage(
                        id: raw.id,
                        title: raw.title,
                        type: pageType,
                        importedPageIDs: importedPageIDs
                    )
                }

                // Sort by date descending (newest first), unparseable at end
                let sorted = confluencePages.sorted { a, b in
                    guard let dateA = a.parsedDate else { return false }
                    guard let dateB = b.parsedDate else { return true }
                    return dateA > dateB
                }

                await MainActor.run {
                    self.pages = sorted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
