//
//  OpenPaste.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import AppKit
import SwiftUI

// MARK: - Layout Constants

/// Default width for the floating panel
private let defaultPanelWidth: CGFloat = 520

// MARK: - CustomPanel
/// Custom NSPanel subclass that can become key window even with utilityWindow style
class CustomPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - AppDelegate
/// Application delegate for handling Dock icon events and application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        NSLog("🚀 AppDelegate.init() called!")
    }
    /// Floating panel reference for showing on Dock icon click
    var floatingPanel: NSPanel?

    /// View model for clipboard data, persistence, and monitoring
    private var viewModel: ClipboardViewModel?

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

        // Setup global hotkey with HotKey library
        setupGlobalHotkey()

        // Create ClipboardViewModel with Core Data persistence
        let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
        let expiryService = ExpiryService(dataStore: dataStore)
        let monitor = ClipboardMonitor { [weak self] content, contentType, sourceApp in
            Task { @MainActor in
                await self?.viewModel?.handleNewClipboardItem(
                    content: content, contentType: contentType, sourceApp: sourceApp)
            }
        }
        viewModel = ClipboardViewModel(
            dataStore: dataStore, monitor: monitor, expiryService: expiryService)

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

    /// Copy content to clipboard without triggering new entry
    /// - Parameter content: The string content to copy
    func copyToClipboard(_ content: String) {
        MainActor.assumeIsolated {
            viewModel?.skipNextChange()
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private func setupGlobalHotkey() {
        NSLog("🔧 Registering global hotkey...")

        // Create hotkey with Command+Shift+V
        hotKey = HotKey(key: .v, modifiers: [.command, .shift], keyDownHandler: { [weak self] in
            NSLog("🔥 Hotkey triggered!")
            self?.toggleFloatingPanel()
        })

        NSLog("✅ Hotkey ⌘⇧V registered successfully!")
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

    // MARK: - Floating Panel Management

    @objc private func showFloatingPanel() {
        // Activate app and bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let panel = floatingPanel {
            let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
            let topBottomMargin: CGFloat = 20

            // Recalculate frame to match screen height with margin
            let panelWidth = panel.contentView?.frame.width ?? defaultPanelWidth
            let panelHeight = screen.height - (topBottomMargin * 2)
            let targetX = screen.maxX - panelWidth
            let targetY = screen.minY + topBottomMargin

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
        // Create the hosting view for SwiftUI with ViewModel
        guard let vm = viewModel else { return }
        let contentView = FloatingPanelView(viewModel: vm) { content in
            self.copyToClipboard(content)
        }
        let hostingView = NSHostingView(rootView: contentView)

        // Get screen dimensions for positioning
        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
        let panelWidth: CGFloat = defaultPanelWidth
        let topBottomMargin: CGFloat = 20
        let panelHeight: CGFloat = screen.height - (topBottomMargin * 2)

        // Target position - flush against right edge, with margin on top/bottom
        let targetX = screen.maxX - panelWidth
        let targetY = screen.minY + topBottomMargin

        // Create panel at target position first
        let panel = CustomPanel(
            contentRect: NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.title = ""
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true

        // Enable transparency for glass effect
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Remove all window decorations and shadows
        panel.hasShadow = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = .clear
        panel.contentView?.layer?.shadowColor = .clear
        panel.contentView?.layer?.shadowOpacity = 0
        panel.contentView?.layer?.shadowRadius = 0
        panel.level = .modalPanel

        // Remove activation frame border
        panel.styleMask.insert(.nonactivatingPanel)

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

    // MARK: - Status Bar

    private func setupStatusBar() {
        NSLog("🔧 Setting up status bar...")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Load custom status bar icon
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true  // Auto-adapt to dark/light mode
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
                button.imageScaling = .scaleProportionallyDown
            } else {
                // Fallback to emoji if icon not found
                button.title = "📋"
            }
            
            button.toolTip = "OpenPaste - 点击打开剪贴板历史\n右键显示菜单"
            
            // Add click gesture to button
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            NSLog("✅ Status bar button created")
        } else {
            NSLog("❌ Failed to create status bar button")
        }

        NSLog("✅ Status bar setup complete")
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Show menu on right click
            let menu = NSMenu()
            let quitItem = NSMenuItem(title: "退出 OpenPaste", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Toggle panel on left click
            toggleFloatingPanel()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - FloatingPanelView

/// View wrapper for the floating panel with sidebar navigation
/// Uses HStack layout: 70pt sidebar + unified content area
struct FloatingPanelView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    let copyHandler: (String) -> Void

    @State private var selectedCategory: CategorySelector = .preset(.recent)

    // MARK: - Computed Properties for Background Effects

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .background(.ultraThinMaterial)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar (floating buttons outside background)
            SidebarView(
                viewModel: viewModel,
                selectedCategory: $selectedCategory
            )
            .frame(width: 250)

            // Right content area with rounded glass background
            UnifiedContentView(
                selectedCategory: $selectedCategory,
                viewModel: viewModel,
                copyHandler: copyHandler
            )
            .frame(maxWidth: .infinity)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - PanelTab

enum PanelTab: String, CaseIterable {
    case history
    case categories
    case settings
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
