import SwiftUI

/// Sidebar view with preset categories and settings
/// Displays a vertical list of category buttons with pinned settings at bottom
struct SidebarView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @Binding var selectedCategory: CategorySelector

    var body: some View {
        VStack(spacing: 0) {
            // Preset category buttons (including favorites)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(PresetCategory.allCases, id: \.self) { preset in
                        CategoryButton(
                            title: preset.customDisplayName ?? preset.displayName,
                            icon: preset.icon,
                            iconColor: preset.iconColor,
                            isSelected: selectedCategory == .preset(preset)
                        ) {
                            selectedCategory = .preset(preset)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }

            Spacer()

            // Settings button (pinned to bottom)
            CategoryButton(
                title: "设置",
                icon: "gearshape",
                isSelected: selectedCategory.isSettings
            ) {
                selectedCategory = .settings
            }
            .padding(.bottom, 12)
        }
        .frame(width: 250)
        .background(Color.clear)
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        viewModel: previewViewModel(),
        selectedCategory: .constant(.preset(.recent))
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
