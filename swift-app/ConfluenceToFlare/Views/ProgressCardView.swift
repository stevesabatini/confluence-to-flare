import SwiftUI

struct ProgressCardView: View {
    let state: PageImportState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack(spacing: 8) {
                statusIcon
                Text(state.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
            }

            // Step list
            if !state.steps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.steps) { step in
                        HStack(spacing: 6) {
                            stepIcon(step: step)
                            Text(step.message)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state.status {
        case .active:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .foregroundStyle(.gray)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func stepIcon(step: PageImportState.StepState) -> some View {
        if step.isError {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        } else if step.isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        }
    }

    private var cardBackground: Color {
        switch state.status {
        case .active: return .clear
        case .done: return .green.opacity(0.03)
        case .skipped: return .gray.opacity(0.05)
        case .error: return .red.opacity(0.03)
        }
    }

    private var borderColor: Color {
        switch state.status {
        case .active: return .blue.opacity(0.3)
        case .done: return .green.opacity(0.2)
        case .skipped: return .gray.opacity(0.2)
        case .error: return .red.opacity(0.3)
        }
    }
}
