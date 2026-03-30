import SwiftUI

/// Image content view for displaying image clipboard items with thumbnail preview
struct ImageView: View {
    let content: String

    private let fixedHeight: CGFloat = 108

    @State private var thumbnailImage: NSImage?
    @State private var imageSize: String?

    var body: some View {
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

                // Size label overlay
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
            .allowsHitTesting(false)  // 让ZStack不拦截手势，事件穿透到GeometryReader外层
        }
        .frame(height: fixedHeight)
        .clipped()
        .onAppear {
            loadImageThumbnail()
        }
    }

    // MARK: - Private Methods

    /// Load image thumbnail from file path
    private func loadImageThumbnail() {
        // Parse JSON array to get file URL
        guard let data = content.data(using: .utf8),
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

#Preview {
    ImageView(content: "[]")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
