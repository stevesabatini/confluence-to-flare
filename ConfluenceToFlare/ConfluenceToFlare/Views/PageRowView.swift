import SwiftUI

struct PageRowView: View {
    let page: ConfluencePage
    let isSelected: Bool
    let isSelectable: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .disabled(!isSelectable)

            // Page info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if !page.displayDate.isEmpty {
                        Text(page.displayDate)
                            .fontWeight(.semibold)
                    }

                    // Type badge
                    Text(page.type.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.15))
                        .foregroundStyle(badgeColor)
                        .clipShape(Capsule())

                    // Imported badge
                    if page.isImported {
                        Text("IMPORTED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Text(page.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Preview button
            Button {
                onPreview()
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Preview release note")
        }
        .padding(.vertical, 4)
        .opacity(isSelectable ? 1.0 : 0.55)
    }

    private var badgeColor: Color {
        switch page.type {
        case .features: return .blue
        case .patch: return .orange
        case .other: return .gray
        }
    }
}
