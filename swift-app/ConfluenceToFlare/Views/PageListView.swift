import SwiftUI

struct PageListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageListViewModel
    var onStartImport: () -> Void
    @State private var previewPage: ConfluencePage?
    @State private var showPreview = false

    var body: some View {
        PersistentSplitView(
            autosaveName: "PageListPreviewSplit",
            showRight: showPreview,
            left: {
                pageListPanel
            },
            right: {
                previewPanel
            }
        )
    }

    // MARK: - Page List Panel

    private var pageListPanel: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(viewModel.pages.count) release note(s) in Confluence")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.loadPages(appState: appState)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh page list")
            }
            .padding()
            .background(.bar)

            Divider()

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Fetching pages from Confluence...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Select All header
                HStack {
                    Toggle(isOn: Binding(
                        get: { viewModel.allSelectableSelected },
                        set: { _ in viewModel.toggleSelectAll() }
                    )) {
                        Text("Select All")
                            .fontWeight(.medium)
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5))

                Divider()

                // Page list
                List(viewModel.pages) { page in
                    PageRowView(
                        page: page,
                        isSelected: viewModel.isSelected(page),
                        isSelectable: viewModel.isSelectable(page),
                        isPreviewActive: previewPage?.id == page.id,
                        onToggle: { viewModel.togglePage(page) },
                        onPreview: {
                            if previewPage?.id == page.id && showPreview {
                                // Tapping eye on the already-previewed page collapses
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPreview = false
                                }
                                previewPage = nil
                            } else {
                                previewPage = page
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPreview = true
                                }
                            }
                        }
                    )
                }
                .listStyle(.plain)

                Divider()

                // Bottom action bar
                HStack {
                    Toggle("Force re-import (overwrite existing)", isOn: $viewModel.forceReimport)
                        .toggleStyle(.checkbox)

                    Spacer()

                    Button {
                        onStartImport()
                    } label: {
                        Text("Import Selected (\(viewModel.selectedCount))")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedCount == 0)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            if let page = previewPage {
                PreviewView(page: page, onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPreview = false
                    }
                    previewPage = nil
                })
            }
        }
    }
}
