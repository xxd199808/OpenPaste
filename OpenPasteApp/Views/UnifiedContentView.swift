import SwiftUI

/// Unified content view that displays filtered clipboard items based on selected category
/// Replaces separate tab views with a single list that filters by category selection
struct UnifiedContentView: View {
    @Binding var selectedCategory: CategorySelector
    @ObservedObject var viewModel: ClipboardViewModel
    let copyHandler: (String) -> Void

    @State private var selectedIndex: Int? = nil

    var body: some View {
        Group {
            if selectedCategory.isSettings {
                // Show settings view
                SettingsView()
            } else {
                // Show filtered content list
                contentView
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if filteredItems.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemView(
                            item: item,
                            onSelect: {
                                selectedIndex = index
                                copyHandler(item.content)
                            }
                        )
                        .contextMenu {
                            categoryMenuContent(for: item)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(emptyStateTitle)
                .font(.title3)
                .foregroundColor(.secondary)

            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredItems: [ClipboardItemData] {
        switch selectedCategory {
        case .preset(let preset):
            // Filter by preset category
            return viewModel.items.filter { preset.matches($0) }

        case .custom(let categoryId):
            // Filter by custom category
            return viewModel.items.filter { $0.categoryId == categoryId }

        case .settings:
            // Settings handled in body
            return []
        }
    }

    private var emptyStateIcon: String {
        switch selectedCategory {
        case .preset(let preset):
            switch preset {
            case .recent: return "doc.on.clipboard"
            case .text: return "doc.text"
            case .code: return "curlybraces"
            case .bash: return "terminal"
            case .image: return "photo"
            case .file: return "doc"
            case .link: return "link"
            case .email: return "envelope"
            case .phoneNumber: return "phone"
            case .colorCode: return "paintpalette"
            case .favorite1, .favorite2, .favorite3, .favorite4, .favorite5: return "star.fill"
            }
        case .custom:
            return "folder"
        case .settings:
            return "gearshape"
        }
    }

    private var emptyStateTitle: String {
        switch selectedCategory {
        case .preset(let preset):
            return "No \(preset.displayName) items"
        case .custom:
            return "No items in this category"
        case .settings:
            return "Settings"
        }
    }

    private var emptyStateMessage: String {
        switch selectedCategory {
        case .preset(let preset):
            switch preset {
            case .recent:
                return "Copy some content to get started"
            default:
                return "No items match this category"
            }
        case .custom:
            return "Drag items here or assign from context menu"
        case .settings:
            return ""
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func categoryMenuContent(for item: ClipboardItemData) -> some View {
        if !viewModel.categories.isEmpty {
            Menu("添加到分类") {
                ForEach(viewModel.categories) { category in
                    Button(category.name) {
                        Task {
                            await viewModel.assignItem(item, toCategory: category.id)
                        }
                    }
                }
            }

            Divider()

            Button("从分类中移除", role: .destructive) {
                Task {
                    await viewModel.removeFromCategory(item)
                }
            }
        } else {
            Button("暂无分类") {
                // TODO: Navigate to categories
            }
            .disabled(true)
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedContentView(
        selectedCategory: .constant(.preset(.recent)),
        viewModel: previewViewModel(),
        copyHandler: { _ in }
    )
}

// MARK: - Preview Helpers

@MainActor
private func previewViewModel() -> ClipboardViewModel {
    let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
    let monitor = ClipboardMonitor(onChange: { _, _, _ in })
    let expiryService = ExpiryService(dataStore: dataStore)
    return ClipboardViewModel(
        dataStore: dataStore,
        monitor: monitor,
        expiryService: expiryService
    )
}
