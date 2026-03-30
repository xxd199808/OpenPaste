import Foundation

/// Data model for clipboard item display (value type for UI layer)
struct ClipboardItemData: Identifiable, Equatable {
    let id: UUID
    let content: String
    let contentType: String
    let sourceApp: String?
    let capturedAt: Date
    let isPinned: Bool
    let categoryId: UUID?  // Category assignment for filtering
    let title: String?  // Rich link title or additional metadata
    let allPasteboardData: Data?  // Complete pasteboard data for restoration
    let allPasteboardTypes: String?  // JSON string of all pasteboard types

    /// Equatable comparison - ignore pasteboard data for equality checks
    static func == (lhs: ClipboardItemData, rhs: ClipboardItemData) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.contentType == rhs.contentType &&
        lhs.sourceApp == rhs.sourceApp &&
        lhs.capturedAt == rhs.capturedAt &&
        lhs.isPinned == rhs.isPinned &&
        lhs.categoryId == rhs.categoryId &&
        lhs.title == rhs.title
    }
}
