import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var viewState: ViewState = .loading
    @State private var pageListVM = PageListViewModel()
    @State private var importVM = ImportViewModel()
    @State private var configError: String = ""

    enum ViewState {
        case loading
        case configError
        case pageSelection
        case importProgress
    }

    var body: some View {
        Group {
            switch viewState {
            case .loading:
                LoadingView()

            case .configError:
                ConfigErrorView(message: configError)

            case .pageSelection:
                PageListView(
                    viewModel: pageListVM,
                    onStartImport: startImport
                )

            case .importProgress:
                ImportProgressView(
                    viewModel: importVM,
                    onBack: {
                        viewState = .pageSelection
                        pageListVM.loadPages(appState: appState)
                    }
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            validateAndLoad()
        }
    }

    private func validateAndLoad() {
        if appState.isSettingsValid {
            viewState = .pageSelection
            pageListVM.loadPages(appState: appState)
        } else {
            configError = "Please configure your Confluence and Flare settings in Settings (Cmd+,)."
            viewState = .configError
        }
    }

    private func startImport() {
        let selectedIDs = Array(pageListVM.selectedPageIDs)
        guard !selectedIDs.isEmpty else { return }

        viewState = .importProgress
        importVM.startImport(
            pageIDs: selectedIDs,
            appState: appState,
            force: pageListVM.forceReimport
        )
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Config Error View

struct ConfigErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Configuration Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Text("Open Settings with Cmd+,")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
