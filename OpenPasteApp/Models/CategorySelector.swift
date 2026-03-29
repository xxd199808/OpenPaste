import Foundation

/// Category selector for unified sidebar navigation
/// Represents either a preset category, custom category, or settings
enum CategorySelector: Equatable {
    case preset(PresetCategory)
    case custom(UUID)
    case settings

    // MARK: - Computed Properties

    /// Unique identifier for the selection
    var id: String {
        switch self {
        case .preset(let preset):
            return "preset_\(preset.rawValue)"
        case .custom(let uuid):
            return "custom_\(uuid.uuidString)"
        case .settings:
            return "settings"
        }
    }

    /// Display name for the selection
    var displayName: String {
        switch self {
        case .preset(let preset):
            return preset.displayName
        case .custom:
            return "自定义分类"
        case .settings:
            return "设置"
        }
    }

    /// SF Symbol icon for the selection
    var icon: String {
        switch self {
        case .preset(let preset):
            return preset.icon
        case .custom:
            return "folder"
        case .settings:
            return "gearshape"
        }
    }

    /// Whether this selection points to settings
    var isSettings: Bool {
        if case .settings = self {
            return true
        }
        return false
    }
}
