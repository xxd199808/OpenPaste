import SwiftUI

// MARK: - SettingsView
/// Settings screen for hotkey, retention period, history size, and theme preferences.
/// All settings persist via UserDefaults and survive app restarts.
struct SettingsView: View {
    // MARK: - Properties

    /// App settings model
    @StateObject private var settings = AppSettings.shared

    /// Showing hotkey customization alert
    @State private var showingHotkeyAlert = false

    /// Showing clear data confirmation alert
    @State private var showingClearDataAlert = false

    /// ViewModel for clearing data
    var viewModel: ClipboardViewModel?

    // MARK: - Computed Properties

    /// Progressive glass background for settings view
    @ViewBuilder
    private var settingsBackground: some View {
        Rectangle().fill(.thinMaterial)
    }

    /// Progressive glass background for settings sections
    @ViewBuilder
    private var sectionBackground: some View {
        Rectangle().fill(.ultraThinMaterial)
    }

    // MARK: - Section Views

    /// Keyboard shortcut section
    private var keyboardShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard")
                .font(.headline)
                .padding(.bottom, 4)

            HStack {
                Text("Keyboard Shortcut")
                    .accessibilityLabel("Global keyboard shortcut")

                Spacer()

                Button(action: { showingHotkeyAlert = true }) {
                    Text(settings.hotkeyDescription)
                        .font(.body.monospaced())
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .accessibilityLabel("Change keyboard shortcut")
                .accessibilityHint("Current shortcut is \(settings.hotkeyDescription)")
            }
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// Data management section
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Management")
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Retention Period")
                        .accessibilityLabel("Clipboard item retention period")

                    Spacer()

                    Text("\(settings.retentionDays) days")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("\(settings.retentionDays) days")
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.retentionDays) },
                        set: { settings.retentionDays = Int($0) }
                    ),
                    in: 7...90,
                    step: 1
                )
                .accessibilityValue("\(settings.retentionDays) days")
                .labelsHidden()

                Text("Items are automatically deleted after this many days, unless pinned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            Divider()

            Button(action: { showingClearDataAlert = true }) {
                Text("Clear All Data")
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Clear all clipboard data")
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// History section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum History Size")
                        .accessibilityLabel("Maximum clipboard history size")

                    Spacer()

                    Text("\(settings.maxHistorySize.formatted()) items")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("\(settings.maxHistorySize.formatted()) items")
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.maxHistorySize) },
                        set: { settings.maxHistorySize = Int($0) }
                    ),
                    in: 1_000...50_000,
                    step: 1_000
                )
                .accessibilityValue("\(settings.maxHistorySize) items")
                .labelsHidden()

                Text("Oldest items are removed when this limit is reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// Theme section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
                .padding(.bottom, 4)

            Picker("Appearance", selection: $settings.theme) {
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
                Text("Auto").tag(AppTheme.auto)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Theme preference")

            Text("Auto matches your system appearance setting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// About section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .padding(.bottom, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenPaste")
                        .font(.headline)

                    Text("Version \(settings.appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Link("View License", destination: URL(string: "https://opensource.org/licenses/MIT")!)
                    .font(.caption)
            }
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                keyboardShortcutSection
                dataManagementSection
                historySection
                themeSection
                aboutSection
            }
            .padding()
        }
        .background(settingsBackground)
        .navigationTitle("Settings")
        .alert("Change Keyboard Shortcut", isPresented: $showingHotkeyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Record") {
                // In production, this would trigger hotkey recording UI
                // For now, we just show a message
            }
        } message: {
            Text("Press the key combination you want to use for showing the clipboard history")
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await viewModel?.clearAllData()
                }
            }
        } message: {
            Text("This will permanently delete all clipboard history. This action cannot be undone.")
        }
    }
}

// MARK: - AppSettings

/// App settings model with UserDefaults persistence
final class AppSettings: ObservableObject {
    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Published Properties

    /// Keyboard shortcut modifiers (bitmask)
    @Published var hotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    /// Keyboard shortcut key code
    @Published var hotkeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyCode, forKey: Keys.hotkeyCode)
        }
    }

    /// Retention period in days (7-90)
    @Published var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: Keys.retentionDays)
        }
    }

    /// Maximum history size (1,000-50,000)
    @Published var maxHistorySize: Int {
        didSet {
            UserDefaults.standard.set(maxHistorySize, forKey: Keys.maxHistorySize)
        }
    }

    /// Theme preference
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
        }
    }

    /// App version
    let appVersion: String

    // MARK: - Computed Properties

    /// Human-readable hotkey description (e.g., "⌘⇧V")
    var hotkeyDescription: String {
        var parts: [String] = []
        if hotkeyModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if hotkeyModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if hotkeyModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if hotkeyModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append("V")
        return parts.joined()
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults into local variables first to avoid
        // accessing self before all stored properties are initialized
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyModifiers))
        self.hotkeyModifiers = modifiers == 0 ? UInt32(cmdKey) | UInt32(shiftKey) : modifiers

        let code = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyCode))
        self.hotkeyCode = code == 0 ? UInt32(kVK_ANSI_V) : code

        let retention = UserDefaults.standard.integer(forKey: Keys.retentionDays)
        self.retentionDays = retention == 0 ? 30 : retention

        let maxHistory = UserDefaults.standard.integer(forKey: Keys.maxHistorySize)
        self.maxHistorySize = maxHistory == 0 ? 10_000 : maxHistory

        if let themeRaw = UserDefaults.standard.string(forKey: Keys.theme),
           let loadedTheme = AppTheme(rawValue: themeRaw) {
            self.theme = loadedTheme
        } else {
            self.theme = .auto
        }

        // App version from Info.plist
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Keys

    enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyCode = "hotkeyCode"
        static let retentionDays = "retentionDays"
        static let maxHistorySize = "maxHistorySize"
        static let theme = "theme"
    }
}

// MARK: - AppTheme

/// App theme options
enum AppTheme: String {
    case light
    case dark
    case auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

import Carbon

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView()
    }
}
