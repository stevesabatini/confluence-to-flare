import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var viewState: ViewState = .splash
    @State private var pageListVM = PageListViewModel()
    @State private var importVM = ImportViewModel()
    @State private var configError: String = ""
    @State private var dataReady = false

    enum ViewState {
        case splash
        case configError
        case pageSelection
        case importProgress
    }

    var body: some View {
        Group {
            switch viewState {
            case .splash:
                SplashView(
                    statusText: pageListVM.loadingPhase,
                    progress: pageListVM.loadingProgress,
                    loadingComplete: dataReady,
                    onReadyToTransition: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            viewState = .pageSelection
                        }
                    }
                )

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
        .onChange(of: pageListVM.isLoading) { _, isLoading in
            if !isLoading && viewState == .splash {
                dataReady = true
            }
        }
    }

    private func validateAndLoad() {
        if appState.isSettingsValid {
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
