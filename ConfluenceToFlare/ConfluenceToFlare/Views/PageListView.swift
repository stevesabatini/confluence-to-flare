import SwiftUI

struct PageListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageListViewModel
    var onStartImport: () -> Void
    @State private var previewPage: ConfluencePage?

    var body: some View {
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
                        onToggle: { viewModel.togglePage(page) },
                        onPreview: { previewPage = page }
                    )
                }
                .listStyle(.plain)
                .sheet(item: $previewPage) { page in
                    PreviewView(page: page)
                }

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
}
