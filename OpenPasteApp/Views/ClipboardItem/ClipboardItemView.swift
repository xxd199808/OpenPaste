import SwiftUI
import AppKit

// MARK: - ClipboardItemView
/// Individual clipboard item cell with support for different content types.
/// Now uses the new Card-based layout with separate header and content areas.
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

    /// Action handler for category change
    var onCategoryChange: ((UUID?) -> Void)?

    /// Action handler for delete
    var onDelete: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ClipboardItemCard(
            item: item,
            onSelect: onSelect,
            onPinToggle: onPinToggle,
            onCategoryChange: onCategoryChange,
            onDelete: onDelete
        )
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
                isPinned: false,
                categoryId: nil
            )
        )

        ClipboardItemView(
            item: ClipboardItemData(
                id: UUID(),
                content: "Pinned item",
                contentType: "public.utf8-plain-text",
                sourceApp: "Finder",
                capturedAt: Date(),
                isPinned: true,
                categoryId: nil
            )
        )
    }
    .padding()
    .frame(width: 300)
}

#Preview("Image Item") {
    ClipboardItemView(
        item: ClipboardItemData(
            id: UUID(),
            content: "Image data",
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            isPinned: false,
            categoryId: nil
        )
    )
    .padding()
    .frame(width: 300)
}

#Preview("File Item") {
    ClipboardItemView(
        item: ClipboardItemData(
            id: UUID(),
            content: "[\"file:///Users/example/Documents/report.pdf\"]",
            contentType: "public.file-url",
            sourceApp: "Finder",
            capturedAt: Date(),
            isPinned: false,
            categoryId: nil
        )
    )
    .padding()
    .frame(width: 300)
}
