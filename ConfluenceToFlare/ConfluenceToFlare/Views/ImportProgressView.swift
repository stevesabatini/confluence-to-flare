import SwiftUI

struct ImportProgressView: View {
    @Bindable var viewModel: ImportViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress bar
            VStack(spacing: 8) {
                Text("Importing \(viewModel.totalPages) release note(s)...")
                    .font(.headline)

                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)

                Text("\(viewModel.completedPages) of \(viewModel.totalPages)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            // Progress cards
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.pageStates) { state in
                            ProgressCardView(state: state)
                                .id(state.id)
                        }

                        // Summary
                        if viewModel.isComplete {
                            summarySection
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.pageStates.count) { _, _ in
                    if let lastID = viewModel.pageStates.last?.id {
                        withAnimation {
                            scrollProxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            // Bottom bar
            if viewModel.isComplete {
                Divider()
                HStack {
                    Spacer()
                    Button("Back to Page List") {
                        onBack()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.bar)
            } else if viewModel.isRunning {
                Divider()
                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Label("Import Complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(viewModel.errorCount > 0 ? .orange : .green)

            Text(viewModel.summaryMessage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Next steps:")
                    .fontWeight(.medium)

                Text("1. Open the Flare project and preview the new topics")
                Text("2. Run a Flare build to verify everything looks correct")
                Text("3. Review the Overview page and Mini-TOC for correct ordering")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
