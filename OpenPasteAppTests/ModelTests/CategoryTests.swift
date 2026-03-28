import XCTest
import CoreData
@testable import PasteApp

/// Unit tests for Category Core Data model
final class CategoryTests: XCTestCase {

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

    func testCategoryCreation() throws {
        // Given: A new Category
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Work"
        category.type = "manual"
        category.icon = "folder"
        category.sortOrder = 0

        // When: Category is saved
        try context.save()

        // Then: Category should have all properties set correctly
        XCTAssertNotNil(category.id)
        XCTAssertEqual(category.name, "Work")
        XCTAssertEqual(category.type, "manual")
        XCTAssertEqual(category.icon, "folder")
        XCTAssertEqual(category.sortOrder, 0)
    }

    func testCategoryAutoType() throws {
        // Given: An auto-generated category for source app
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Safari"
        category.type = "auto"
        category.icon = "safari"
        category.sortOrder = 1

        // When: Category is saved
        try context.save()

        // Then: Category should be marked as auto type
        XCTAssertEqual(category.type, "auto")
        XCTAssertEqual(category.name, "Safari")
    }

    func testCategorySortOrder() throws {
        // Given: Multiple categories with different sort orders
        let category1 = Category(context: context)
        category1.id = UUID()
        category1.name = "First"
        category1.type = "manual"
        category1.sortOrder = 0

        let category2 = Category(context: context)
        category2.id = UUID()
        category2.name = "Second"
        category2.type = "manual"
        category2.sortOrder = 1

        try context.save()

        // When: Fetching categories sorted by sortOrder
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        let fetchedCategories = try context.fetch(fetchRequest)

        // Then: Categories should be in correct order
        XCTAssertEqual(fetchedCategories.count, 2)
        XCTAssertEqual(fetchedCategories[0].name, "First")
        XCTAssertEqual(fetchedCategories[1].name, "Second")
    }

    func testCategoryWithItemsRelationship() throws {
        // Given: A category with multiple clipboard items
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.type = "manual"
        category.sortOrder = 0

        var items: [ClipboardItem] = []

        for i in 1...3 {
            let item = ClipboardItem(context: context)
            item.id = UUID()
            item.content = "Item \(i)".data(using: .utf8)
            item.contentType = "public.utf8-plain-text"
            item.capturedAt = Date()
            item.expiresAt = Date()
            item.isPinned = false
            item.category = category
            items.append(item)
        }

        try context.save()

        // When: Accessing items through relationship
        let fetchedItems = category.items?.allObjects as? [ClipboardItem]

        // Then: All items should be related to the category
        XCTAssertNotNil(fetchedItems)
        XCTAssertEqual(fetchedItems?.count, 3)
        XCTAssertEqual(fetchedItems?.allSatisfy { $0.category == category }, true)
    }

    func testCategoryDeletion() throws {
        // Given: A category
        let category = Category(context: context)
        let categoryId = UUID()
        category.id = categoryId
        category.name = "To Delete"
        category.type = "manual"
        category.sortOrder = 0

        try context.save()

        // When: Category is deleted
        context.delete(category)
        try context.save()

        // Then: Category should not exist in context
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)

        let fetchedCategories = try context.fetch(fetchRequest)

        XCTAssertEqual(fetchedCategories.count, 0)
    }

    func testMultipleCategoriesFetch() throws {
        // Given: Multiple categories of different types
        let autoCategory = Category(context: context)
        autoCategory.id = UUID()
        autoCategory.name = "Safari"
        autoCategory.type = "auto"
        autoCategory.sortOrder = 0

        let manualCategory = Category(context: context)
        manualCategory.id = UUID()
        manualCategory.name = "Personal"
        manualCategory.type = "manual"
        manualCategory.sortOrder = 1

        try context.save()

        // When: Fetching all categories
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let fetchedCategories = try context.fetch(fetchRequest)

        // Then: Both categories should be fetched
        XCTAssertEqual(fetchedCategories.count, 2)

        let autoFetched = fetchedCategories.filter { $0.type == "auto" }
        let manualFetched = fetchedCategories.filter { $0.type == "manual" }

        XCTAssertEqual(autoFetched.count, 1)
        XCTAssertEqual(manualFetched.count, 1)
    }
}
