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
        HStack(alignment: .top, spacing: 12) {
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
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Content preview
                Text(previewText)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.primary)

                // Timestamp
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .allowsHitTesting(false)

            Spacer()
        }
        .padding(12)
        .background(
            Color(isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onTapGesture {
                    onTap()
                }
        )
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