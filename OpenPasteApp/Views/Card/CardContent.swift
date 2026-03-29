import SwiftUI

/// Card content area displaying clipboard item preview with fixed height
struct CardContent: View {
    let item: ClipboardItemData

    private let fixedHeight: CGFloat = 108

    @State private var thumbnailImage: NSImage?
    @State private var imageSize: String?

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
            .lineLimit(6)
            .multilineTextAlignment(.leading)
    }

    private var imageContent: some View {
        // Thumbnail image filling the content area
        GeometryReader { geometry in
            ZStack {
                // Image layer
                Group {
                    if let thumbnail = thumbnailImage {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        Color.secondary.opacity(0.1)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.largeTitle)
                            }
                    }
                }

                // Size label - using absolute positioning
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if let imageSize = imageSize {
                            Text(imageSize)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 3, x: 1, y: 1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(height: fixedHeight)
        .clipped()
        .onAppear {
            loadImageThumbnail()
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

    /// Load image thumbnail from file path
    private func loadImageThumbnail() {
        guard item.contentType == "public.image" || item.contentType == "public.tiff" || item.contentType == "public.png" else {
            return
        }

        // Parse JSON array to get file URL
        guard let data = item.content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let urlString = urls.first,
              let url = URL(string: urlString) else {
            return
        }

        // Load image from file
        DispatchQueue.global(qos: .userInitiated).async {
            if let imageData = try? Data(contentsOf: url),
               let image = NSImage(data: imageData) {
                // Create thumbnail
                let thumbnailSize = NSSize(width: 128, height: 128)
                if let thumbnail = createThumbnail(from: image, size: thumbnailSize) {
                    DispatchQueue.main.async {
                        self.thumbnailImage = thumbnail
                        // Extract image size info
                        if let representation = image.representations.first {
                            let pixelsWidth = representation.pixelsWide
                            let pixelsHeight = representation.pixelsHigh
                            self.imageSize = "\(pixelsWidth) × \(pixelsHeight)"
                        }
                    }
                }
            }
        }
    }

    /// Create thumbnail from image
    private func createThumbnail(from image: NSImage, size: NSSize) -> NSImage? {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
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
