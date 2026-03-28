//
//  OpenPaste.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import AppKit
import SwiftUI

// MARK: - AppDelegate
/// Application delegate for handling Dock icon events and application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        NSLog("🚀 AppDelegate.init() called!")
    }
    /// Floating panel reference for showing on Dock icon click
    var floatingPanel: NSPanel?

    /// Badge label for showing clipboard item count
    private var badgeLabel: NSView?

    /// Number of items from the last 24 hours (for badge display)
    var recentItemCount: Int = 0 {
        didSet {
            updateDockBadge()
        }
    }

    /// In-memory clipboard items for display
    private var clipboardItems: [(String, Date)] = []

    /// Flag to track when app is triggering clipboard paste (to avoid duplicates)
    private var isInternalPaste = false

    /// Status bar menu item
    private var statusItem: NSStatusItem?

    /// HotKey instance
    private var hotKey: HotKey?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 OpenPaste launched!")

        // Setup status bar FIRST - this is critical
        setupStatusBar()

        // Hide all windows except our floating panel
        NSApplication.shared.windows.forEach { window in
            window.setIsVisible(false)
        }

        // Setup Dock icon click handler
        setupDockIconHandler()

        // Create badge overlay for item count
        setupDockBadge()

        // Setup global hotkey with HotKey library
        setupGlobalHotkey()

        // Start clipboard monitoring (simplified version)
        startSimpleClipboardMonitoring()

        NSLog("✅ OpenPaste setup complete")

        // Show the floating panel initially so user sees it's working
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showFloatingPanel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup hotkey
        hotKey = nil
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure main window stays hidden when app becomes active
        NSApplication.shared.windows.forEach { window in
            if window !== floatingPanel {
                window.setIsVisible(false)
            }
        }
    }

    // MARK: - Simple Clipboard Monitoring

    private func startSimpleClipboardMonitoring() {
        let pasteboard = NSPasteboard.general
        var lastChangeCount = pasteboard.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentChangeCount = pasteboard.changeCount
            if currentChangeCount != lastChangeCount {
                lastChangeCount = currentChangeCount

                // Skip if this was triggered by the app itself
                if self.isInternalPaste {
                    self.isInternalPaste = false
                    return
                }

                // Get clipboard content
                if let stringContent = pasteboard.string(forType: .string), !stringContent.isEmpty {
                    // Avoid duplicate entries
                    if self.clipboardItems.isEmpty || self.clipboardItems[0].0 != stringContent {
                        // Add to in-memory storage
                        self.clipboardItems.insert((stringContent, Date()), at: 0)
                        self.recentItemCount = self.clipboardItems.count

                        // Update floating panel if visible
                        self.updateFloatingPanelContent()

                        print("✅ Clipboard captured: \(stringContent.prefix(50))...")
                    }
                }
            }
        }
    }

    /// Copy content to clipboard without triggering new entry
    /// - Parameter content: The string content to copy
    func copyToClipboard(_ content: String) {
        isInternalPaste = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Called when Dock icon is clicked
        // Show floating panel even if no windows are visible
        showFloatingPanel()
        return true
    }

    // MARK: - Dock Icon Management

    private func setupDockIconHandler() {
        // Enable Dock icon (LSUIElement = false in Info.plist)
        // Dock icon clicks are handled by applicationShouldHandleReopen
    }

    private func setupDockBadge() {
        // Badge is shown using NSApplication.dockTile.badgeLabel
        // This property is a String, so we'll update it in updateDockBadge()
    }

    private func setupGlobalHotkey() {
        NSLog("🔧 Registering global hotkey...")

        // Create hotkey with Command+Shift+V
        hotKey = HotKey(key: .v, modifiers: [.command, .shift], keyDownHandler: { [weak self] in
            NSLog("🔥 Hotkey triggered!")
            self?.toggleFloatingPanel()
        })

        NSLog("✅ Hotkey ⌘⇧V registered successfully!")
        updateStatusTitle("📋✅")
    }

    private func updateStatusTitle(_ title: String) {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = title
        }
    }

    private func toggleFloatingPanel() {
        if floatingPanel == nil {
            showFloatingPanel()
            return
        }

        if let panel = floatingPanel, panel.isVisible {
            hideFloatingPanel()
        } else {
            showFloatingPanel()
        }
    }

    private func updateDockBadge() {
        if recentItemCount > 0 {
            NSApplication.shared.dockTile.badgeLabel = "\(recentItemCount)"
        } else {
            NSApplication.shared.dockTile.badgeLabel = nil
        }
    }

    // MARK: - Floating Panel Management

    @objc private func showFloatingPanel() {
        // Activate app and bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let panel = floatingPanel {
            let screen = NSScreen.main?.visibleFrame ?? NSRect.zero

            // Use the panel's content view size to get accurate dimensions
            // This is more reliable than panel.frame when window is off-screen
            let panelWidth = panel.contentView?.frame.width ?? 400
            let panelHeight = panel.contentView?.frame.height ?? 500
            let targetX = screen.maxX - panelWidth
            let targetY = (screen.height - panelHeight) / 2

            // Set the panel frame to the correct size and position off-screen
            let offScreenFrame = NSRect(x: screen.maxX, y: targetY, width: panelWidth, height: panelHeight)
            panel.setFrame(offScreenFrame, display: false)

            // Make panel visible
            panel.makeKeyAndOrderFront(nil)
            panel.level = .modalPanel

            // Animate in from right
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                let targetFrame = NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            createFloatingPanel()
        }
    }

    private func createFloatingPanel() {
        // Create the hosting view for SwiftUI with clipboard data and copy handler
        let contentView = FloatingPanelView(items: clipboardItems) { content in
            self.copyToClipboard(content)
        }
        let hostingView = NSHostingView(rootView: contentView)

        // Get screen dimensions for positioning
        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = screen.height * 0.7

        // Target position - flush against right edge
        let targetX = screen.maxX - panelWidth
        let targetY = (screen.height - panelHeight) / 2

        // Create panel at target position first
        let panel = NSPanel(
            contentRect: NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight),
            styleMask: [.resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.title = ""
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Use modalPanel level - stays above normal windows but allows interaction
        panel.level = .modalPanel

        // Don't hide panel when it loses focus (we'll handle it manually)
        panel.hidesOnDeactivate = false

        // Prevent window from being moved below other windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Store reference
        floatingPanel = panel

        // Show the panel
        panel.makeKeyAndOrderFront(nil)

        // Slide-in animation from right
        let startFrame = NSRect(x: screen.maxX, y: targetY, width: panelWidth, height: panelHeight)
        panel.setFrame(startFrame, display: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight), display: true)
        }

        // Add click-outside observer
        addClickOutsideObserver()
    }

    private func addClickOutsideObserver() {
        // Use global monitor to detect clicks anywhere on screen
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  let panel = self.floatingPanel,
                  panel.isVisible else {
                return
            }

            // Convert screen coordinates to check if click is outside panel
            let clickPoint = event.locationInWindow
            let panelFrame = panel.frame

            // Check if click is outside the panel
            if !panelFrame.contains(clickPoint) {
                self.hideFloatingPanel()
            }
        }

        // Also monitor local events within the app
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  let panel = self.floatingPanel,
                  panel.isVisible else {
                return event
            }

            // Check if the event's window is not our panel
            if event.window !== panel {
                // Get click location in screen coordinates
                let screenLocation = event.locationInWindow
                if let eventWindow = event.window {
                    let windowFrame = eventWindow.frame
                    let clickInScreen = NSPoint(
                        x: windowFrame.origin.x + screenLocation.x,
                        y: windowFrame.origin.y + screenLocation.y
                    )

                    // Check if click is outside panel
                    if !panel.frame.contains(clickInScreen) {
                        self.hideFloatingPanel()
                    }
                }
            }

            return event
        }
    }

    private func hideFloatingPanel() {
        guard let panel = floatingPanel else { return }

        let currentFrame = panel.frame
        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero

        // Slide-out animation to the right
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: screen.maxX, y: currentFrame.origin.y))
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    /// Update the floating panel content when clipboard items change
    func updateFloatingPanelContent() {
        guard let panel = floatingPanel,
              let hostingView = panel.contentView as? NSHostingView<FloatingPanelView> else {
            return
        }

        // Update the view with new data and copy handler
        let newContentView = FloatingPanelView(items: clipboardItems) { content in
            self.copyToClipboard(content)
        }
        hostingView.rootView = newContentView
    }

    /// Update the recent item count (called by ClipboardViewModel)
    /// - Parameter count: Number of items captured in the last 24 hours
    func updateRecentItemCount(_ count: Int) {
        recentItemCount = count
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        NSLog("🔧 Setting up status bar...")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "📋"
            button.toolTip = "OpenPaste - Click to open clipboard history"
            NSLog("✅ Status bar button created: \(button.title)")
        } else {
            NSLog("❌ Failed to create status bar button")
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开剪贴板历史", action: #selector(showFloatingPanel), keyEquivalent: "v")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出 OpenPaste", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu

        NSLog("✅ Status bar menu created with \(menu.numberOfItems) items")
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - FloatingPanelView

/// View wrapper for the floating panel that contains the clipboard list
struct FloatingPanelView: View {
    let items: [(String, Date)]
    let copyHandler: (String) -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("OpenPaste - Clipboard History")
                    .font(.headline)

                Spacer()

                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Clipboard items list
            if items.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No clipboard items yet")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Copy some text to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            ClipboardItemRow(
                                content: item.0,
                                timestamp: item.1,
                                index: index,
                                isSelected: index == selectedIndex,
                                copyHandler: copyHandler,
                                onTap: {
                                    selectedIndex = index
                                    copyHandler(item.0)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - ClipboardItemRow

struct ClipboardItemRow: View {
    let content: String
    let timestamp: Date
    let index: Int
    let isSelected: Bool
    let copyHandler: (String) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selected checkmark or index badge
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .allowsHitTesting(false)
            } else {
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Content preview
                Text(previewText)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.primary)

                // Timestamp
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .allowsHitTesting(false)

            Spacer()
        }
        .padding(12)
        .background(
            Color(isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onTapGesture {
                    onTap()
                }
        )
    }

    private var previewText: String {
        if content.isEmpty {
            return "[Empty content]"
        }
        return content
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.on.clipboard")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("OpenPaste")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your clipboard companion")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Press ⌘⇧V to open clipboard history")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
