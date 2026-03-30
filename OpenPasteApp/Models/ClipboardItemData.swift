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
}
