import SwiftUI

/// Complete clipboard item card combining header and content
struct ClipboardItemCard: View {
    let item: ClipboardItemData
    var onSelect: (() -> Void)?
    var onPinToggle: (() -> Void)?
    var onCategoryChange: ((UUID?) -> Void)?
    var onDelete: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    var body: some View {
        Button(action: { onSelect?() }) {
            VStack(spacing: 0) {
                CardHeader(
                    contentType: item.contentType,
                    sourceApp: item.sourceApp,
                    capturedAt: item.capturedAt,
                    categoryId: item.categoryId,
                    title: item.title,
                    onCategorySelect: onCategoryChange,
                    onTitleChange: onTitleChange
                )

                CardContent(item: item)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(pinOverlay)
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
                .background(item.isPinned ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Pin Overlay

    @ViewBuilder
    private var pinOverlay: some View {
        if item.isPinned {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
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
            title: nil
        )
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
            title: nil
        )
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
            title: nil
        )
    )
    .frame(width: 300)
    .padding()
}
