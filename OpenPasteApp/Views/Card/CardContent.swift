import SwiftUI

/// Card content area displaying clipboard item preview with fixed height
struct CardContent: View {
    let item: ClipboardItemData

    private let fixedHeight: CGFloat = 72

    var body: some View {
        Group {
            switch item.contentType {
            case "public.utf8-plain-text", "public.text":
                textContent
            case "public.image", "public.tiff", "public.png":
                imageContent
            case "public.file-url":
                fileContent
            case "public.url":
                urlContent
            default:
                defaultContent
            }
        }
        .frame(height: fixedHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(contentBackground)
    }

    // MARK: - Content Types

    private var textContent: some View {
        Text(item.content.isEmpty ? "[Empty content]" : item.content)
            .font(.system(size: 13))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }

    private var imageContent: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Image")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                if let imageSize = extractImageSize() {
                    Text(imageSize)
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                }
            }
        }
    }

    private var fileContent: some View {
        HStack(spacing: 12) {
            // File icon
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                if let fileName = extractFileName(from: item.content) {
                    Text(fileName)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                } else {
                    Text("File")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
            }
        }
    }

    private var urlContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                Text(item.content)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(2)
            }
        }
    }

    private var defaultContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipboard content")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            Text(item.contentType)
                .font(.caption2)
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var contentBackground: some View {
        Color.white
    }

    // MARK: - Helper Methods

    /// Extract file name from file URL content
    private func extractFileName(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let firstURL = urls.first,
              let url = URL(string: firstURL) else {
            return nil
        }
        return url.lastPathComponent
    }

    /// Extract image size info if available
    private func extractImageSize() -> String? {
        // For now, return a placeholder
        // In the future, this could parse actual image dimensions
        return nil
    }
}

// MARK: - Preview

#Preview("Text Content") {
    CardContent(item: ClipboardItemData(
        id: UUID(),
        content: "Example clipboard text content that spans multiple lines and should be displayed properly",
        contentType: "public.utf8-plain-text",
        sourceApp: "Safari",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil
    ))
    .frame(width: 300)
}

#Preview("Image Content") {
    CardContent(item: ClipboardItemData(
        id: UUID(),
        content: "Image data placeholder",
        contentType: "public.image",
        sourceApp: "Photos",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil
    ))
    .frame(width: 300)
}

#Preview("File Content") {
    CardContent(item: ClipboardItemData(
        id: UUID(),
        content: "[\"file:///Users/example/Documents/report.pdf\"]",
        contentType: "public.file-url",
        sourceApp: "Finder",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil
    ))
    .frame(width: 300)
}
