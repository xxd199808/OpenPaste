import SwiftUI
import AppKit

// MARK: - ClipboardItemView
/// Individual clipboard item cell with support for different content types.
/// Handles text, image, and file content with lazy loading of binary data.
struct ClipboardItemView: View {
    // MARK: - Properties

    /// The clipboard item data to display
    let item: ClipboardItemData

    /// Whether the item is currently visible (for lazy loading)
    var isVisible: Bool = true

    /// Action handler for item selection
    var onSelect: (() -> Void)?

    /// Action handler for pin toggle
    var onPinToggle: (() -> Void)?

    /// Action handler for delete
    var onDelete: (() -> Void)?

    // MARK: - Body

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 12) {
                // Pin icon for pinned items
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                        .accessibilityLabel("Pinned item")
                } else {
                    // Placeholder for alignment
                    Image(systemName: "pin.fill")
                        .foregroundColor(.clear)
                        .font(.caption)
                        .accessibilityHidden(true)
                }

                // Content preview based on type
                contentView(for: item)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Trailing chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isPinned ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        item.isPinned ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { onPinToggle?() }) {
                Label(
                    item.isPinned ? "Unpin" : "Pin",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }
            Divider()
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Content Views

    /// Returns the appropriate content view based on content type
    /// - Parameter item: The clipboard item data
    /// - Returns: A view representing the content
    @ViewBuilder
    private func contentView(for item: ClipboardItemData) -> some View {
        switch item.contentType {
        case "public.utf8-plain-text", "public.text":
            textPreview(for: item)
        case "public.image", "public.tiff", "public.png":
            imagePreview(for: item)
        case "public.file-url":
            filePreview(for: item)
        default:
            defaultPreview(for: item)
        }
    }

    /// Text content preview
    private func textPreview(for item: ClipboardItemData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content)
                .lineLimit(2)
                .font(.body)
                .accessibilityLabel("Text content: \(item.content)")

            metadataView(for: item)
        }
    }

    /// Image content preview with thumbnail
    private func imagePreview(for item: ClipboardItemData) -> some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Image thumbnail")

            VStack(alignment: .leading, spacing: 4) {
                Text("Image")
                    .font(.body)

                metadataView(for: item)
            }
        }
    }

    /// File content preview with file icon
    private func filePreview(for item: ClipboardItemData) -> some View {
        HStack(spacing: 12) {
            // File icon
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("File icon")

            VStack(alignment: .leading, spacing: 4) {
                if let fileName = extractFileName(from: item.content) {
                    Text(fileName)
                        .lineLimit(1)
                        .font(.body)
                        .accessibilityLabel("File name: \(fileName)")
                } else {
                    Text("File")
                        .font(.body)
                }

                metadataView(for: item)
            }
        }
    }

    /// Default preview for unknown content types
    private func defaultPreview(for item: ClipboardItemData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard content")
                .font(.body)

            Text(item.contentType)
                .font(.caption)
                .foregroundColor(.secondary)

            metadataView(for: item)
        }
    }

    /// Metadata view showing source app and capture time
    private func metadataView(for item: ClipboardItemData) -> some View {
        HStack(spacing: 8) {
            if let sourceApp = item.sourceApp {
                Image(systemName: "app")
                    .font(.caption2)
                Text(sourceApp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "clock")
                .font(.caption2)
            Text(item.capturedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    /// Extract file name from file URL content
    /// - Parameter content: File URL string
    /// - Returns: File name if URL is valid, nil otherwise
    private func extractFileName(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let firstURL = urls.first,
              let url = URL(string: firstURL) else {
            return nil
        }
        return url.lastPathComponent
    }
}

// MARK: - Preview

#Preview("Text Item") {
    VStack(spacing: 8) {
        ClipboardItemView(
            item: ClipboardItemData(
                id: UUID(),
                content: "Example clipboard text content that spans multiple lines",
                contentType: "public.utf8-plain-text",
                sourceApp: "Safari",
                capturedAt: Date().addingTimeInterval(-300),
                isPinned: false
            )
        )

        ClipboardItemView(
            item: ClipboardItemData(
                id: UUID(),
                content: "Pinned item",
                contentType: "public.utf8-plain-text",
                sourceApp: "Finder",
                capturedAt: Date(),
                isPinned: true
            )
        )
    }
    .padding()
}

#Preview("Image Item") {
    ClipboardItemView(
        item: ClipboardItemData(
            id: UUID(),
            content: "Image data",
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            isPinned: false
        )
    )
    .padding()
}

#Preview("File Item") {
    ClipboardItemView(
        item: ClipboardItemData(
            id: UUID(),
            content: "[\"file:///Users/example/Documents/report.pdf\"]",
            contentType: "public.file-url",
            sourceApp: "Finder",
            capturedAt: Date(),
            isPinned: false
        )
    )
    .padding()
}
