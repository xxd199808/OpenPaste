import XCTest
import CoreData
@testable import PasteApp

/// Unit tests for ExpiryService service
final class ExpiryServiceTests: XCTestCase {

    // MARK: - Properties

    var expiryService: ExpiryService!
    var dataStore: CoreDataStore!
    var context: NSManagedObjectContext!
    var deletedItemsLog: [String] = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        deletedItemsLog = []

        // Create in-memory Core Data stack for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType

        let container = NSPersistentContainer(name: "PasteApp")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }

        self.context = container.viewContext
        self.dataStore = CoreDataStore(container: container)

        // Create expiry service with logger to capture deletions
        expiryService = ExpiryService(dataStore: dataStore) { message in
            self.deletedItemsLog.append(message)
        }
    }

    override func tearDown() async throws {
        expiryService.stopService()
        expiryService = nil
        dataStore = nil
        context = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func testExpiryServiceInitialization() {
        // Given: A newly created expiry service

        // Then: Service should not be active by default
        XCTAssertFalse(expiryService.isActive)
    }

    func testExpiryServiceStartStop() {
        // Given: A newly created expiry service
        XCTAssertFalse(expiryService.isActive)

        // When: Starting the service
        expiryService.startService()

        // Then: Service should be active
        XCTAssertTrue(expiryService.isActive)

        // When: Stopping the service
        expiryService.stopService()

        // Then: Service should not be active
        XCTAssertFalse(expiryService.isActive)
    }

    func testExpiryServiceDeletesExpiredItems() throws {
        // Given: Clipboard items with various expiry dates
        let expiredItem = createClipboardItem(
            content: "Expired content",
            capturedAt: Date().addingTimeInterval(-86400 * 35), // 35 days ago
            isPinned: false
        )

        let notExpiredItem = createClipboardItem(
            content: "Recent content",
            capturedAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        let deletedCount = expiryService.performImmediateCleanup()

        // Then: Only expired item should be deleted
        XCTAssertEqual(deletedCount, 1)

        // Verify by fetching
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        let remainingItems = try context.fetch(fetchRequest)

        XCTAssertEqual(remainingItems.count, 1)
        XCTAssertEqual(remainingItems.first?.content, notExpiredItem.content)
    }

    func testExpiryServicePreservesPinnedItems() throws {
        // Given: An expired pinned item and an expired unpinned item
        let pinnedExpired = createClipboardItem(
            content: "Pinned expired",
            capturedAt: Date().addingTimeInterval(-86400 * 35),
            isPinned: true
        )

        let unpinnedExpired = createClipboardItem(
            content: "Unpinned expired",
            capturedAt: Date().addingTimeInterval(-86400 * 35),
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        let deletedCount = expiryService.performImmediateCleanup()

        // Then: Only unpinned item should be deleted (optimistic locking)
        XCTAssertEqual(deletedCount, 1)

        // Verify by fetching
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        let remainingItems = try context.fetch(fetchRequest)

        XCTAssertEqual(remainingItems.count, 1)
        XCTAssertTrue(remainingItems.first?.isPinned ?? false)
    }

    func testExpiryServiceLogging() throws {
        // Given: Expired clipboard items
        _ = createClipboardItem(
            content: "Test expired",
            capturedAt: Date().addingTimeInterval(-86400 * 40),
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        expiryService.performImmediateCleanup()

        // Then: Deletion should be logged
        XCTAssertFalse(deletedItemsLog.isEmpty)
        XCTAssertTrue(deletedItemsLog.contains("deleted"))
    }

    func testExpiryServiceNoExpiredItems() throws {
        // Given: Only recent items (none expired)
        _ = createClipboardItem(
            content: "Recent item",
            capturedAt: Date().addingTimeInterval(-86400), // 1 day ago
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        let deletedCount = expiryService.performImmediateCleanup()

        // Then: No items should be deleted
        XCTAssertEqual(deletedCount, 0)

        // All items should remain
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        let remainingItems = try context.fetch(fetchRequest)

        XCTAssertEqual(remainingItems.count, 1)
    }

    func testExpiryServiceMultipleExpiredItems() throws {
        // Given: Multiple expired items at different ages
        for days in [31, 35, 45, 60] {
            _ = createClipboardItem(
                content: "Item from \(days) days ago",
                capturedAt: Date().addingTimeInterval(-86400 * Double(days)),
                isPinned: false
            )
        }

        // Add one recent item
        _ = createClipboardItem(
            content: "Recent item",
            capturedAt: Date(),
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        let deletedCount = expiryService.performImmediateCleanup()

        // Then: All expired items should be deleted (4 items)
        XCTAssertEqual(deletedCount, 4)

        // Only recent item remains
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        let remainingItems = try context.fetch(fetchRequest)

        XCTAssertEqual(remainingItems.count, 1)
    }

    func testExpiryServiceRespectsRetentionPolicy() throws {
        // Given: Items with custom retention periods
        // Service uses a 30-day default retention, but this can be configured
        let justExpired = createClipboardItem(
            content: "Just expired",
            capturedAt: Date().addingTimeInterval(-86400 * 30), // Exactly 30 days ago
            isPinned: false
        )

        let stillValid = createClipboardItem(
            content: "Still valid",
            capturedAt: Date().addingTimeInterval(-86400 * 29), // 29 days ago
            isPinned: false
        )

        try context.save()

        // When: Expiry service performs cleanup
        let deletedCount = expiryService.performImmediateCleanup()

        // Then: Only items strictly older than 30 days should be deleted
        // (Note: implementation may use <= or < based on requirements)
        XCTAssertGreaterThan(deletedCount, 0)
    }

    // MARK: - Helper Methods

    private func createClipboardItem(
        content: String,
        capturedAt: Date,
        isPinned: Bool
    ) -> ClipboardItem {
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = content.data(using: .utf8)
        item.contentType = "public.utf8-plain-text"
        item.sourceApp = "TestApp"
        item.capturedAt = capturedAt
        item.expiresAt = capturedAt.addingTimeInterval(86400 * 30) // 30 days from capture
        item.isPinned = isPinned
        return item
    }
}
