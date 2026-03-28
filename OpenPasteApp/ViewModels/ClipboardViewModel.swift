import Foundation
import SwiftUI
import Combine
import CoreData

// MARK: - ClipboardViewModel
/// View model that bridges UI and services with reactive state management.
/// Implements loading states, error handling, and uses ClipboardDataStore protocol.
@MainActor
final class ClipboardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Clipboard items displayed in the UI
    @Published var items: [ClipboardItemData] = []

    /// Current search query text
    @Published var searchQuery: String = "" {
        didSet {
            applyFilters()
        }
    }

    /// Selected content type filter
    @Published var selectedContentType: String? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Selected date range filter
    @Published var selectedDateRange: DateRange? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Selected source app filter
    @Published var selectedSourceApp: String? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    /// Error message for display in alerts
    @Published var errorMessage: String? = nil

    /// Whether error alert is showing
    @Published var showingError: Bool = false

    /// Available content types for filter dropdown
    @Published var availableContentTypes: [String] = []

    /// Available source apps for filter dropdown
    @Published var availableSourceApps: [String] = []

    /// Number of items from last 24 hours (for Dock badge)
    @Published var recentItemCount: Int = 0

    /// Available categories for categorizing items
    @Published var categories: [CategoryData] = []

    // MARK: - Properties

    /// Data store for clipboard operations
    private let dataStore: ClipboardDataStore

    /// Clipboard monitor for capturing new items
    private let monitor: ClipboardMonitor

    /// Expiry service for cleanup
    private let expiryService: ExpiryService

    /// All items (unfiltered) for filtering
    private var allItems: [ClipboardItemData] = []

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize the view model with required services
    /// - Parameters:
    ///   - dataStore: Data store for clipboard operations
    ///   - monitor: Clipboard monitor for capturing new items
    ///   - expiryService: Expiry service for cleanup
    init(
        dataStore: ClipboardDataStore,
        monitor: ClipboardMonitor,
        expiryService: ExpiryService
    ) {
        self.dataStore = dataStore
        self.monitor = monitor
        self.expiryService = expiryService

        // Setup clipboard monitoring
        setupMonitoring()

        // Load initial data
        Task {
            await loadInitialData()
            await loadCategories()
        }
    }

    // MARK: - Public Methods

    /// Refresh the clipboard items list
    func refresh() async {
        isLoading = true

        do {
            let fetchedItems = try dataStore.fetchItems(
                predicate: nil,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: nil
            )

            allItems = fetchedItems.map { $0.toData() }
            applyFilters()
            updateAvailableFilters()

            // Update recent item count for Dock badge
            updateRecentItemCount()

        } catch {
            showError("Failed to load clipboard items: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Delete an item from clipboard history
    /// - Parameter item: The item to delete
    func deleteItem(_ item: ClipboardItemData) async {
        isLoading = true

        do {
            // Find the corresponding NSManagedObject
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1
            )

            if let nsItem = fetchedItems.first {
                try dataStore.deleteItem(nsItem)

                // Remove from local arrays
                allItems.removeAll { $0.id == item.id }
                items.removeAll { $0.id == item.id }
                updateRecentItemCount()
            }

        } catch {
            showError("Failed to delete item: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Toggle pin state for an item
    /// - Parameter item: The item to pin/unpin
    func togglePin(for item: ClipboardItemData) async {
        isLoading = true

        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1
            )

            if let nsItem = fetchedItems.first {
                nsItem.isPinned = !item.isPinned
                try dataStore.saveItem(nsItem)

                // Update local arrays
                if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                    allItems[index] = nsItem.toData()
                }
                applyFilters()
            }

        } catch {
            showError("Failed to update item: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingError = false
    }

    /// Signal to skip the next clipboard change detection (before writing to pasteboard)
    func skipNextChange() {
        monitor.skipNextChange()
    }

    /// Assign an item to a category
    /// - Parameters:
    ///   - item: The item to categorize
    ///   - categoryId: The category ID to assign
    func assignItem(_ item: ClipboardItemData, toCategory categoryId: UUID) async {
        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1
            )

            if let nsItem = fetchedItems.first {
                // Find the category entity
                let categories = try dataStore.fetchCategories()
                if let category = categories.first(where: { $0.id == categoryId }) {
                    nsItem.category = category
                    try dataStore.saveItem(nsItem)

                    // Refresh to update local arrays with the new category information
                    await refresh()
                }
            }
        } catch {
            showError("Failed to assign item: \(error.localizedDescription)")
        }
    }

    /// Remove item from its category
    /// - Parameter item: The item to uncategorize
    func removeFromCategory(_ item: ClipboardItemData) async {
        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1
            )

            if let nsItem = fetchedItems.first {
                nsItem.category = nil
                try dataStore.saveItem(nsItem)

                // Refresh to update local arrays with the new category information
                await refresh()
            }
        } catch {
            showError("Failed to remove from category: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods - Setup

    private func setupMonitoring() {
        monitor.startMonitoring()
        expiryService.startService()
    }

    private func loadInitialData() async {
        isLoading = true

        do {
            let fetchedItems = try dataStore.fetchItems(
                predicate: nil,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: nil
            )

            allItems = fetchedItems.map { $0.toData() }
            applyFilters()
            updateAvailableFilters()
            updateRecentItemCount()

        } catch {
            // Check if it's a clipboard access denied error
            if (error as NSError).code == -100 {
                showError("Clipboard access denied. Please grant OpenPaste permission to access your clipboard in System Preferences > Privacy & Security > Clipboard")
            } else {
                showError("Failed to load clipboard items: \(error.localizedDescription)")
            }
        }

        isLoading = false
    }

    func loadCategories() async {
        do {
            let fetched = try dataStore.fetchCategories()
            categories = fetched.map { cat in
                CategoryData(
                    id: cat.id,
                    name: cat.name,
                    type: cat.type == "auto" ? .auto : .manual,
                    icon: cat.icon ?? "folder",
                    sortOrder: Int(cat.sortOrder)
                )
            }
        } catch {
            // Silently fail - categories might not exist yet
            categories = []
        }
    }

    // MARK: - Private Methods - Data Handling

    func handleNewClipboardItem(content: Data, contentType: String, sourceApp: String?) async {
        // Save to Core Data
        let context = dataStore.viewContext
        let newItem = ClipboardItem(context: context)
        newItem.id = UUID()
        newItem.content = content
        newItem.contentType = contentType
        newItem.sourceApp = sourceApp
        newItem.capturedAt = Date()
        newItem.isPinned = false
        newItem.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

        do {
            try dataStore.saveItem(newItem)
        } catch {
            showError("Failed to save clipboard item: \(error.localizedDescription)")
        }

        await refresh()
    }

    private func applyFilters() {
        isLoading = true

        Task {
            let predicate = SearchPredicateBuilder.buildPredicate(
                searchText: searchQuery,
                contentType: selectedContentType,
                dateRange: selectedDateRange,
                sourceApp: selectedSourceApp
            )

            do {
                let fetchedItems = try dataStore.fetchItems(
                    predicate: predicate,
                    sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                    limit: nil
                )

                items = fetchedItems.map { $0.toData() }
            } catch {
                showError("Failed to filter items: \(error.localizedDescription)")
            }

            isLoading = false
        }
    }

    private func updateAvailableFilters() {
        // Extract unique content types
        let contentTypes = Set(allItems.map { $0.contentType })
        availableContentTypes = contentTypes.sorted()

        // Extract unique source apps
        let apps = Set(allItems.compactMap { $0.sourceApp })
        availableSourceApps = apps.sorted()
    }

    private func updateRecentItemCount() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        recentItemCount = allItems.filter { item in
            item.capturedAt > yesterday
        }.count
    }

    // MARK: - Private Methods - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    // MARK: - Public Methods - Category Management

    /// Fetch all categories from the data store
    /// - Returns: Array of category entities
    func fetchCategories() throws -> [Category] {
        return try dataStore.fetchCategories()
    }

    /// Fetch clipboard items with optional filtering
    /// - Parameters:
    ///   - predicate: Optional NSPredicate for filtering
    ///   - sortDescriptors: Optional sort descriptors
    ///   - limit: Optional limit on number of items
    /// - Returns: Array of clipboard item entities
    func fetchItems(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?,
        limit: Int?
    ) throws -> [ClipboardItem] {
        return try dataStore.fetchItems(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: limit
        )
    }

    /// Create a new category
    /// - Parameters:
    ///   - name: Category name
    ///   - type: Category type (auto or manual)
    /// - Returns: The created category entity
    func createCategory(name: String, type: String) throws -> Category {
        return try dataStore.createCategory(name: name, type: type)
    }

    /// Save a clipboard item to the data store
    /// - Parameter item: The clipboard item to save
    func saveItem(_ item: ClipboardItem) throws {
        try dataStore.saveItem(item)
    }
}

// MARK: - ClipboardItem Extension

/// Extension to convert NSManagedObject to ClipboardItemData
extension ClipboardItem {
    func toData() -> ClipboardItemData {
        ClipboardItemData(
            id: self.id ?? UUID(),
            content: String(data: self.content, encoding: .utf8) ?? "",
            contentType: self.contentType,
            sourceApp: self.sourceApp,
            capturedAt: self.capturedAt ?? Date(),
            isPinned: self.isPinned
        )
    }
}
