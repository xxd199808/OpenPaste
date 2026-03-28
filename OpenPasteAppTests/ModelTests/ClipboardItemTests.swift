import XCTest
import CoreData
@testable import PasteApp

/// Unit tests for ClipboardItem Core Data model
final class ClipboardItemTests: XCTestCase {

    // MARK: - Properties

    var persistentContainer: NSPersistentContainer!
    var context: NSManagedObjectContext!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

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

        self.persistentContainer = container
        self.context = container.viewContext
    }

    override func tearDown() async throws {
        context = nil
        persistentContainer = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func testClipboardItemCreation() throws {
        // Given: A new ClipboardItem
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = "Test content".data(using: .utf8)
        item.contentType = "public.utf8-plain-text"
        item.sourceApp = "TestApp"
        item.capturedAt = Date()
        item.isPinned = false
        item.expiresAt = Date().addingTimeInterval(86400 * 30) // 30 days from now

        // When: Item is saved
        try context.save()

        // Then: Item should have all properties set correctly
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.contentType, "public.utf8-plain-text")
        XCTAssertEqual(item.sourceApp, "TestApp")
        XCTAssertFalse(item.isPinned)
        XCTAssertNotNil(item.content)
    }

    func testClipboardItemPinnedState() throws {
        // Given: A clipboard item
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = Data()
        item.contentType = "public.utf8-plain-text"
        item.capturedAt = Date()
        item.expiresAt = Date()
        item.isPinned = false

        // When: Item is pinned
        item.isPinned = true
        try context.save()

        // Then: Item should reflect pinned state
        XCTAssertTrue(item.isPinned)
    }

    func testClipboardItemExpiryDate() throws {
        // Given: A clipboard item with custom expiry
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = Data()
        item.contentType = "public.utf8-plain-text"
        item.capturedAt = Date()
        item.isPinned = false

        let futureDate = Date().addingTimeInterval(86400 * 7) // 7 days from now
        item.expiresAt = futureDate

        // When: Item is saved
        try context.save()

        // Then: Expiry date should be set correctly
        XCTAssertEqual(item.expiresAt, futureDate)
    }

    func testClipboardItemCategoryRelationship() throws {
        // Given: A clipboard item and a category
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = Data()
        item.contentType = "public.utf8-plain-text"
        item.capturedAt = Date()
        item.expiresAt = Date()
        item.isPinned = false

        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.type = "manual"
        category.sortOrder = 0

        // When: Category is assigned to item
        item.category = category
        try context.save()

        // Then: Relationship should be established
        XCTAssertEqual(item.category, category)
    }

    func testMultipleClipboardItemsFetch() throws {
        // Given: Multiple clipboard items
        var items: [ClipboardItem] = []

        for i in 1...5 {
            let item = ClipboardItem(context: context)
            item.id = UUID()
            item.content = "Item \(i)".data(using: .utf8)
            item.contentType = "public.utf8-plain-text"
            item.sourceApp = "TestApp"
            item.capturedAt = Date()
            item.expiresAt = Date()
            item.isPinned = i == 1 // Pin first item
            items.append(item)
        }

        try context.save()

        // When: Fetching all items
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        let fetchedItems = try context.fetch(fetchRequest)

        // Then: All items should be fetched
        XCTAssertEqual(fetchedItems.count, 5)
        XCTAssertEqual(fetchedItems.filter { $0.isPinned }.count, 1)
    }

    func testClipboardItemWithLargeContent() throws {
        // Given: An item with large binary content (simulating image)
        let largeContent = Data(repeating: 0xFF, count: 1024 * 1024) // 1 MB

        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.content = largeContent
        item.contentType = "public.image"
        item.capturedAt = Date()
        item.expiresAt = Date()
        item.isPinned = false

        // When: Item is saved
        try context.save()

        // Then: Large content should be stored successfully
        XCTAssertNotNil(item.content)
        XCTAssertEqual(item.content?.count, 1024 * 1024)
    }
}
