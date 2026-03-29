import SwiftUI

// MARK: - ClipboardItemRow

/// Individual row view for a clipboard item with index and selection support
struct ClipboardItemRow: View {
    let content: String
    let timestamp: Date
    let index: Int
    let isSelected: Bool
    let copyHandler: (String) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Selected checkmark or index badge
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .allowsHitTesting(false)
            } else {
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Content preview
                Text(previewText)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                // Timestamp
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .allowsHitTesting(false)

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Progressive Glass Effects

    @ViewBuilder
    private var badgeBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
        } else {
            Color.secondary.opacity(0.2)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        }
    }

    private var previewText: String {
        if content.isEmpty {
            return "[Empty content]"
        }
        return content
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}