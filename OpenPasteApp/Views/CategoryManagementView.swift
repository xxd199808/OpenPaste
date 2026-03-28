import SwiftUI
import CoreData

// MARK: - CategoryManagementView
/// Category management UI with auto-categorization and manual folder creation.
/// Supports drag-and-drop to organize clipboard items into categories.
struct CategoryManagementView: View {
    // MARK: - Properties

    /// Available categories
    @State private var categories: [CategoryData] = []

    /// Currently selected category
    @State private var selectedCategory: CategoryData?

    /// Showing new category sheet
    @State private var showingNewCategorySheet = false

    /// New category name input
    @State private var newCategoryName = ""

    /// New category type selection
    @State private var newCategoryType: CategoryType = .manual

    /// Clipboard items filtered by selected category
    @State private var filteredItems: [ClipboardItemData] = []

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Category sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Categories")
                        .font(.headline)
                        .accessibilityLabel("Categories list")

                    Spacer()

                    Button(action: { showingNewCategorySheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create new category")
                }
                .padding()

                Divider()

                // Category list
                List(categories, selection: $selectedCategory) { category in
                    CategoryRow(
                        category: category,
                        itemCount: itemCount(for: category)
                    )
                    .tag(category)
                    .contextMenu {
                        Button(category.type == .manual ? "Edit" : "View") {
                            // Edit/view category
                        }

                        if category.type == .manual {
                            Button("Delete", role: .destructive) {
                                deleteCategory(category)
                            }
                        }
                    }
                    .onDrop(
                        of: [.text],
                        delegate: CategoryDropDelegate(
                            category: category,
                          onItemsDropped: { items in
                                moveItemsToCategory(items, category: category)
                            }
                        )
                    )
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // Items in selected category
            VStack(spacing: 0) {
                if let selected = selectedCategory {
                    // Category header
                    HStack {
                        Text(selected.name)
                            .font(.headline)

                        if selected.type == .auto {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(itemCount(for: selected)) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    Divider()

                    // Items list
                    if filteredItems.isEmpty {
                        emptyStateView(for: selected)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredItems, id: \.id) { item in
                                    ClipboardItemRow(item: item)
                                        .draggable(item.id.uuidString)
                                }
                            }
                        }
                    }
                } else {
                    // No category selected
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Select a category to view items")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .sheet(isPresented: $showingNewCategorySheet) {
            newCategorySheet
        }
    }

    // MARK: - Sheet Views

    private var newCategorySheet: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $newCategoryType) {
                    Text("Manual").tag(CategoryType.manual)
                    Text("Auto").tag(CategoryType.auto)
                }
                .pickerStyle(.segmented)

                Text("Manual categories are created by you. Auto categories are automatically created based on the source application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNewCategorySheet = false
                        newCategoryName = ""
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCategory()
                        showingNewCategorySheet = false
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyStateView(for category: CategoryData) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No items in \(category.name)")
                .foregroundColor(.secondary)

            if category.type == .manual {
                Text("Drag items here to add them to this category")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func loadCategories() {
        // Mock data for now
        // In production, this would fetch from ClipboardRepository
        categories = [
            CategoryData(
                id: UUID(),
                name: "All Items",
                type: .auto,
                icon: "doc.on.doc",
                sortOrder: 0
            ),
            CategoryData(
                id: UUID(),
                name: "Safari",
                type: .auto,
                icon: "safari",
                sortOrder: 1
            ),
            CategoryData(
                id: UUID(),
                name: "Finder",
                type: .auto,
                icon: "finder",
                sortOrder: 2
            ),
            CategoryData(
                id: UUID(),
                name: "Work",
                type: .manual,
                icon: "folder",
                sortOrder: 3
            ),
            CategoryData(
                id: UUID(),
                name: "Personal",
                type: .manual,
                icon: "folder",
                sortOrder: 4
            )
        ]

        // Select first category by default
        if selectedCategory == nil, let first = categories.first {
            selectedCategory = first
            loadItems(for: first)
        }
    }

    private func loadItems(for category: CategoryData) {
        // Mock data for now
        // In production, this would fetch from ClipboardRepository
        filteredItems = (1...5).map { index in
            ClipboardItemData(
                id: UUID(),
                content: "Item \(index) in \(category.name)",
                contentType: "public.utf8-plain-text",
                sourceApp: category.name,
                capturedAt: Date().addingTimeInterval(-Double(index * 3600)),
                isPinned: false
            )
        }
    }

    private func itemCount(for category: CategoryData) -> Int {
        // Mock implementation
        // In production, this would query from data store
        return Int.random(in: 1...50)
    }

    private func createCategory() {
        let newCategory = CategoryData(
            id: UUID(),
            name: newCategoryName,
            type: newCategoryType,
            icon: newCategoryType == .manual ? "folder" : "app",
            sortOrder: categories.count
        )

        categories.append(newCategory)
        newCategoryName = ""
    }

    private func deleteCategory(_ category: CategoryData) {
        categories.removeAll { $0.id == category.id }

        if selectedCategory?.id == category.id {
            selectedCategory = categories.first
        }
    }

    private func moveItemsToCategory(_ items: [String], category: CategoryData) {
        // In production, this would update the ClipboardItem's category relationship
        print("Moved \(items.count) items to \(category.name)")
    }
}

// MARK: - CategoryData

/// Data model for category display
struct CategoryData: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: CategoryType
    let icon: String
    let sortOrder: Int
}

// MARK: - CategoryType

/// Category type (auto-generated or manually created)
enum CategoryType: String {
    case auto
    case manual
}

// MARK: - CategoryRow

/// Individual category row in the sidebar
struct CategoryRow: View {
    let category: CategoryData
    let itemCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(category.name)

            Spacer()

            Text("\(itemCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("\(itemCount) items")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CategoryDropDelegate

/// Drop delegate for dragging items into categories
struct CategoryDropDelegate: DropDelegate {
    let category: CategoryData
    let onItemsDropped: ([String]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }

    func performDrop(info: DropInfo) -> Bool {
        var items: [String] = []

        if let item = info.itemProviders(for: [.text]).first {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let text = String(data: data, encoding: .utf8) {
                    items.append(text)
                }
            }
        }

        // Simulate async load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onItemsDropped(items)
        }

        return true
    }
}

// MARK: - Preview

#Preview {
    CategoryManagementView()
}
