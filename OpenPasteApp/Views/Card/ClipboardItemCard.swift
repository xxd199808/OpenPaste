import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Complete clipboard item card combining header and content
struct ClipboardItemCard: View {
    let item: ClipboardItemData
    var onCategoryChange: ((UUID?) -> Void)?
    var onDelete: (() -> Void)?
    var onTitleChange: ((String) -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(
                contentType: item.contentType,
                sourceApp: item.sourceApp,
                capturedAt: item.capturedAt,
                categoryId: item.categoryId,
                title: item.title,
                onCategorySelect: onCategoryChange,
                onTitleChange: onTitleChange,
                onDelete: onDelete
            )

            CardContent(item: item)
                .onTapGesture {
                    onCopy?()
                }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Card Background

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
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Preview

#Preview("Text Card") {
    ClipboardItemCard(
        item: ClipboardItemData(
            id: UUID(),
            content: "Example clipboard text content that spans multiple lines",
            contentType: "public.utf8-plain-text",
            sourceApp: "Safari",
            capturedAt: Date().addingTimeInterval(-300),
            isPinned: false,
            categoryId: nil,
            title: nil,
            allPasteboardData: nil,
            allPasteboardTypes: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}

#Preview("Pinned Card") {
    ClipboardItemCard(
        item: ClipboardItemData(
            id: UUID(),
            content: "Pinned item with important content",
            contentType: "public.utf8-plain-text",
            sourceApp: "Finder",
            capturedAt: Date(),
            isPinned: true,
            categoryId: nil,
            title: nil,
            allPasteboardData: nil,
            allPasteboardTypes: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}

#Preview("Image Card") {
    ClipboardItemCard(
        item: ClipboardItemData(
            id: UUID(),
            content: "Image data",
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            isPinned: false,
            categoryId: nil,
            title: nil,
            allPasteboardData: nil,
            allPasteboardTypes: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}
