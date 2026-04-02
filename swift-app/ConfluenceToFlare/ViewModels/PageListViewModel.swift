import Foundation
import Observation
import os

@Observable
final class PageListViewModel {
    var pages: [ConfluencePage] = []
    var selectedPageIDs: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?
    var forceReimport: Bool = false

    /// Loading progress (0.0–1.0) for splash screen binding
    var loadingProgress: Double = 0.0
    /// Current loading phase description
    var loadingPhase: String = ""

    private let logger = Logger(subsystem: "ConfluenceToFlare", category: "Timing")

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
        loadingProgress = 0.0
        loadingPhase = "CONNECTING TO CONFLUENCE"
        errorMessage = nil
        selectedPageIDs.removeAll()

        Task {
            let totalStart = ContinuousClock.now

            do {
                let settings = appState.settings

                // Phase 1: Local disk scan for imported pages
                let diskStart = ContinuousClock.now
                let releaseNotesDir = settings.resolvedReleaseNotesDir()
                let importedPageIDs = releaseNotesDir != nil
                    ? ImportEngine.getImportedPageIDs(releaseNotesDir: releaseNotesDir!)
                    : Set<String>()
                let diskElapsed = diskStart.duration(to: ContinuousClock.now)
                logger.info("⏱ Disk scan (imported page IDs): \(diskElapsed)")

                await MainActor.run {
                    self.loadingProgress = 0.1
                    self.loadingPhase = "LOADING RELEASE NOTES"
                }

                // Phase 2: Confluence API tree walk (progress 0.1–0.85)
                let apiStart = ContinuousClock.now
                let rawPages = try await client.getReleaseFeaturePages(
                    productionParentID: settings.productionParentID,
                    onProgress: { fraction in
                        Task { @MainActor in
                            self.loadingProgress = 0.1 + fraction * 0.75
                        }
                    }
                )
                let apiElapsed = apiStart.duration(to: ContinuousClock.now)
                logger.info("⏱ Confluence API tree walk: \(apiElapsed) (\(rawPages.count) pages)")

                await MainActor.run {
                    self.loadingProgress = 0.85
                    self.loadingPhase = "PREPARING WORKSPACE"
                }

                // Phase 3: Transform and sort
                let sortStart = ContinuousClock.now
                let confluencePages = rawPages.map { raw in
                    let pageType: ConfluencePage.PageType = raw.type == "patch" ? .patch : .features
                    return ConfluencePage(
                        id: raw.id,
                        title: raw.title,
                        type: pageType,
                        importedPageIDs: importedPageIDs
                    )
                }

                let sorted = confluencePages.sorted { a, b in
                    guard let dateA = a.parsedDate else { return false }
                    guard let dateB = b.parsedDate else { return true }
                    return dateA > dateB
                }
                let sortElapsed = sortStart.duration(to: ContinuousClock.now)
                logger.info("⏱ Transform + sort: \(sortElapsed)")

                let totalElapsed = totalStart.duration(to: ContinuousClock.now)
                logger.info("⏱ TOTAL load time: \(totalElapsed)")

                // Store timing report in UserDefaults for easy retrieval
                let report = """
                === Load Timing Report ===
                Date: \(Date())
                Pages found: \(rawPages.count)
                Imported IDs on disk: \(importedPageIDs.count)

                Disk scan (imported IDs):  \(diskElapsed)
                Confluence API tree walk:  \(apiElapsed)
                Transform + sort:          \(sortElapsed)
                ─────────────────────────
                TOTAL:                     \(totalElapsed)
                """
                UserDefaults.standard.set(report, forKey: "lastLoadTimingReport")

                await MainActor.run {
                    self.loadingProgress = 1.0
                    self.pages = sorted
                    self.isLoading = false
                }
            } catch {
                let totalElapsed = totalStart.duration(to: ContinuousClock.now)
                let errorReport = "LOAD FAILED after \(totalElapsed): \(error.localizedDescription)"
                UserDefaults.standard.set(errorReport, forKey: "lastLoadTimingReport")

                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
