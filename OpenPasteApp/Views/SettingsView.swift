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

    // MARK: - Body

    var body: some View {
        Form {
            // Keyboard Shortcut Section
            Section {
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
            } header: {
                Text("Keyboard")
            }

            // Retention Period Section
            Section {
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
                        value: $settings.retentionDays,
                        in: 7...90,
                        step: 1
                    ) {
                        Text("Retention Period")
                            .accessibilityHidden(true)
                    }
                    .accessibilityValue("\(settings.retentionDays) days")

                    Text("Items are automatically deleted after this many days, unless pinned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Data Management")
            }

            // History Size Section
            Section {
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
                    ) {
                        Text("Maximum History Size")
                            .accessibilityHidden(true)
                    }
                    .accessibilityValue("\(settings.maxHistorySize) items")

                    Text("Oldest items are removed when this limit is reached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("History")
            }

            // Theme Section
            Section {
                Picker("Appearance", selection: $settings.theme) {
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                    Text("Auto").tag(AppTheme.auto)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Theme preference")
            } header: {
                Text("Theme")
            } footer: {
                Text("Auto matches your system appearance setting")
                    .font(.caption)
            }

            // About Section
            Section {
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
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
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
        if hotkeyModifiers & cmdKey != 0 { parts.append("⌘") }
        if hotkeyModifiers & shiftKey != 0 { parts.append("⇧") }
        if hotkeyModifiers & optionKey != 0 { parts.append("⌥") }
        if hotkeyModifiers & controlKey != 0 { parts.append("⌃") }
        parts.append("V")
        return parts.joined()
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults or set defaults
        self.hotkeyModifiers = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyModifiers))
        if self.hotkeyModifiers == 0 {
            self.hotkeyModifiers = cmdKey | shiftKey // Default: ⌘⇧V
        }

        self.hotkeyCode = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyCode))
        if self.hotkeyCode == 0 {
            self.hotkeyCode = kVK_ANSI_V // Default: V key
        }

        self.retentionDays = UserDefaults.standard.integer(forKey: Keys.retentionDays)
        if self.retentionDays == 0 {
            self.retentionDays = 30 // Default: 30 days
        }

        self.maxHistorySize = UserDefaults.standard.integer(forKey: Keys.maxHistorySize)
        if self.maxHistorySize == 0 {
            self.maxHistorySize = 10_000 // Default: 10,000 items
        }

        if let themeRaw = UserDefaults.standard.string(forKey: Keys.theme),
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        } else {
            self.theme = .auto // Default: Auto
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

// MARK: - Carbon Constants (re-export from HotkeyService)

let cmdKey: UInt32 = 0x100
let shiftKey: UInt32 = 0x200
let optionKey: UInt32 = 0x400
let controlKey: UInt32 = 0x1000
let kVK_ANSI_V: UInt32 = 9

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView()
    }
}
