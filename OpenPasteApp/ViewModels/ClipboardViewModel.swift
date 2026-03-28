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
    @Published(publishes: recentItemCount) var recentItemCountInternal: Int = 0
    var recentItemCount: Int {
        get { recentItemCountInternal }
        set { recentItemCountInternal = newValue }
    }

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
        }
    }

    /// Convenience initializer with default services
    convenience init() {
        // Create Core Data store
        let dataStore = CoreDataStore(modelName: "PasteApp")

        // Create clipboard monitor
        let monitor = ClipboardMonitor { [weak self] content, contentType, sourceApp in
            Task { @MainActor in
                await self?.handleNewClipboardItem(content: content, contentType: contentType, sourceApp: sourceApp)
            }
        }

        // Create expiry service
        let expiryService = ExpiryService(dataStore: dataStore)

        self.init(dataStore: dataStore, monitor: monitor, expiryService: expiryService)
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

    // MARK: - Private Methods - Data Handling

    private func handleNewClipboardItem(content: Data, contentType: String, sourceApp: String?) async {
        // In production, this would save to Core Data via dataStore
        // For now, we'll just add to the local array and refresh
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
