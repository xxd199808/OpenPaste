import SwiftUI
import AppKit

// MARK: - FloatingPanelView
/// A floating panel that displays the clipboard history.
/// Uses NSPanel for non-activating panel behavior (doesn't take focus from other apps).
struct FloatingPanelView: View {
    // MARK: - Properties

    /// Whether the panel is currently visible
    @State private var isVisible = false

    /// The NSPanel hosting this SwiftUI view
    @State private var panel: NSPanel?

    /// Hotkey service for showing/hiding the panel
    @StateObject private var hotkeyService: HotkeyService

    /// Clipboard items to display (placeholder for now)
    @State private var clipboardItems: [String] = []

    // MARK: - Initialization

    /// Initialize the floating panel view
    /// - Parameters:
    ///   - keyCode: Virtual key code for the hotkey (default: Cmd+Shift+V)
    ///   - modifiers: Modifier flags for the hotkey
    init(keyCode: UInt32 = kVK_ANSI_V, modifiers: UInt32 = cmdKey | shiftKey) {
        // Create hotkey service with toggle handler
        let hotkey = HotkeyService(keyCode: keyCode, modifiers: modifiers) { [self] in
            togglePanel()
        }
        _hotkeyService = StateObject(wrappedValue: hotkey)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("OpenPaste")
                    .font(.headline)
                    .accessibilityLabel("Clipboard history")

                Spacer()

                Button(action: hidePanel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal)

            Divider()

            // Placeholder content - will be replaced with ClipboardListView
            VStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Clipboard history will appear here")
                    .foregroundColor(.secondary)

                Text("Press \(hotkeyModifierDescription) to toggle this panel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 400)
        .onAppear {
            setupPanel()
        }
    }

    // MARK: - Computed Properties

    /// Human-readable description of the hotkey modifiers
    private var hotkeyModifierDescription: String {
        var parts: [String] = []
        if hotkeyService.modifiers & cmdKey != 0 { parts.append("⌘") }
        if hotkeyService.modifiers & shiftKey != 0 { parts.append("⇧") }
        if hotkeyService.modifiers & optionKey != 0 { parts.append("⌥") }
        if hotkeyService.modifiers & controlKey != 0 { parts.append("⌃") }
        return parts.joined() + "V"
    }

    // MARK: - Panel Management

    /// Setup the NSPanel with appropriate properties
    private func setupPanel() {
        guard panel == nil else { return }

        let nsPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        // Configure panel for floating behavior
        nsPanel.isFloatingPanel = true
        nsPanel.level = .floating
        nsPanel.backgroundColor = .windowBackgroundColor
        nsPanel.isMovableByWindowBackground = false

        // Make panel non-activating (doesn't steal focus from other apps)
        nsPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Center the panel on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = nsPanel.frame.size
            nsPanel.setFrameOrigin(
                NSPoint(
                    x: screenFrame.midX - panelSize.width / 2,
                    y: screenFrame.midY - panelSize.height / 2
                )
            )
        }

        // Host SwiftUI view in the panel
        let hostingView = NSHostingView(rootView: self)
        nsPanel.contentView = hostingView

        panel = nsPanel
    }

    /// Toggle panel visibility
    private func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    /// Show the floating panel
    private func showPanel() {
        guard let nsPanel = panel else {
            setupPanel()
            guard let nsPanel = panel else { return }
            nsPanel.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }

        nsPanel.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    /// Hide the floating panel
    private func hidePanel() {
        panel?.orderOut(nil)
        isVisible = false
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelView()
}
