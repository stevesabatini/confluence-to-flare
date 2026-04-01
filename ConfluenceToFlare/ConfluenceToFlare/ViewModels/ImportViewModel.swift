import Foundation
import Observation

/// State for a single page being imported.
struct PageImportState: Identifiable {
    let id: String // pageID
    let index: Int
    var title: String = ""
    var steps: [StepState] = []
    var status: Status = .active

    enum Status {
        case active
        case done
        case skipped
        case error
    }

    struct StepState: Identifiable {
        let id: String // step name
        var message: String
        var isDone: Bool = false
        var isError: Bool = false
    }
}

@Observable
final class ImportViewModel {
    var totalPages: Int = 0
    var completedPages: Int = 0
    var pageStates: [PageImportState] = []
    var isRunning: Bool = false
    var isComplete: Bool = false
    var importedCount: Int = 0
    var skippedCount: Int = 0
    var errorCount: Int = 0
    var summaryMessage: String = ""

    private var importTask: Task<Void, Never>?

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(completedPages) / Double(totalPages)
    }

    func startImport(
        pageIDs: [String],
        appState: AppState,
        force: Bool
    ) {
        guard let client = appState.createConfluenceClient() else { return }

        isRunning = true
        isComplete = false
        totalPages = pageIDs.count
        completedPages = 0
        pageStates = []
        importedCount = 0
        skippedCount = 0
        errorCount = 0

        let settings = appState.settings

        importTask = Task {
            let stream = ImportEngine.runImport(
                pageIDs: pageIDs,
                client: client,
                settings: settings,
                force: force
            )

            for await event in stream {
                await MainActor.run {
                    handleEvent(event)
                }
            }

            await MainActor.run {
                isRunning = false
            }
        }
    }

    func cancel() {
        importTask?.cancel()
        importTask = nil
        isRunning = false
    }

    private func handleEvent(_ event: ImportEvent) {
        switch event {
        case .start(let total, _):
            totalPages = total

        case .pageStart(let index, let pageID, let title, _):
            let state = PageImportState(id: pageID, index: index, title: title)
            pageStates.append(state)

        case .step(let index, let step, let message):
            guard let stateIndex = pageStates.firstIndex(where: { $0.index == index }) else { return }

            // If step ends with "_done", mark the previous step as done
            if step.hasSuffix("_done") {
                let baseStep = String(step.dropLast(5))
                if let stepIndex = pageStates[stateIndex].steps.firstIndex(where: { $0.id == baseStep }) {
                    pageStates[stateIndex].steps[stepIndex].isDone = true
                    pageStates[stateIndex].steps[stepIndex].message = message
                }
            } else {
                // Add a new step
                let stepState = PageImportState.StepState(id: step, message: message)
                pageStates[stateIndex].steps.append(stepState)
            }

        case .skip(let index, _, let message):
            let state = PageImportState(
                id: "skip-\(index)",
                index: index,
                title: message,
                status: .skipped
            )
            pageStates.append(state)
            completedPages += 1

        case .pageDone(let index, _, _):
            if let stateIndex = pageStates.firstIndex(where: { $0.index == index }) {
                pageStates[stateIndex].status = .done
            }
            completedPages += 1

        case .error(let index, let message):
            if index >= 0, let stateIndex = pageStates.firstIndex(where: { $0.index == index }) {
                pageStates[stateIndex].status = .error
                let errorStep = PageImportState.StepState(id: "error", message: message, isError: true)
                pageStates[stateIndex].steps.append(errorStep)
                completedPages += 1
            }

        case .complete(let imported, let skipped, let errors, let message):
            importedCount = imported
            skippedCount = skipped
            errorCount = errors
            summaryMessage = message
            isComplete = true
        }
    }
}
