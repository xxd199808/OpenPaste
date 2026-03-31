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

// MARK: - Global Status Item
// 🔥 macOS 15 要求：必须在全局作用域持有强引用
var statusItem: NSStatusItem?
// 🔥 macOS 15 多线程保护：防止系统在后台线程强制回收
let statusBarLock = NSLock()

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

    /// HotKey instance
    private var hotKey: HotKey?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 OpenPaste launched!")

        // Setup status bar FIRST - this is critical
        // 🔥 macOS 15 启动时序 Bug: 延迟 0.3 秒确保 NSStatusBar 系统已准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupStatusBar()
        }

        // Hide all windows except our floating panel
        NSApplication.shared.windows.forEach { window in
            window.setIsVisible(false)
        }

        // Setup global hotkey with HotKey library
        setupGlobalHotkey()

        // Create ClipboardViewModel with Core Data persistence
        let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
        let expiryService = ExpiryService(dataStore: dataStore)
        let monitor = ClipboardMonitor { [weak self] content, contentType, sourceApp, title, allPasteboardData in
            Task { @MainActor in
                await self?.viewModel?.handleNewClipboardItem(
                    content: content, contentType: contentType, sourceApp: sourceApp, title: title, allPasteboardData: allPasteboardData)
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
    /// - Parameter item: The clipboard item data to restore (including all pasteboard formats)
    func copyToClipboard(_ item: ClipboardItemData) {
        MainActor.assumeIsolated {
            NSLog("📋 copyToClipboard called for item:")
            NSLog("   - ID: \(item.id)")
            NSLog("   - Content: \(item.content.prefix(50))...")
            NSLog("   - contentType: \(item.contentType)")
            NSLog("   - CapturedAt: \(item.capturedAt)")

            // Skip change detection BEFORE writing to pasteboard (critical ordering!)
            viewModel?.skipNextChange()

            // Restore complete pasteboard data with all formats
            guard let allPasteboardDataValue = item.allPasteboardData else {
                NSLog("❌ No allPasteboardData available for item: \(item.id)")
                return
            }

            NSLog("✅ Found allPasteboardData: \(allPasteboardDataValue.count) bytes")

            guard let pasteboardData = PasteboardData.decode(from: allPasteboardDataValue) else {
                NSLog("❌ Failed to decode PasteboardData from \(allPasteboardDataValue.count) bytes")
                return
            }

            NSLog("✅ Decoded PasteboardData with \(pasteboardData.types.count) types")
            NSLog("   Writing to pasteboard...")

            // Restore all formats for accurate pasting in source apps
            PasteboardWriter.writeAll(pasteboardData, to: NSPasteboard.general)
            NSLog("✅ Restored complete pasteboard with \(pasteboardData.types.count) types")

            // Update current clipboard item tracking
            viewModel?.setCurrentClipboardItem(item.id)
        }
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
            statusItem?.button?.title = title
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
        // 🔥 macOS 15 多线程保护：防止系统在后台线程强制回收
        statusBarLock.lock()
        defer { statusBarLock.unlock() }

        NSLog("🔧 Setting up status bar (macOS 15 safe: action-only, no menu)")

        // 稳定长度
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            NSLog("❌ Status bar button unavailable")
            return
        }

        // 图标 / 文字
        if let icon = NSImage(named: "StatusBarIcon") {
            icon.isTemplate = true  // 自动适配明暗模式
            icon.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
        } else {
            button.title = "📋"
        }

        button.toolTip = "OpenPaste - 点击打开剪贴板历史"

        // 🔥 核心：纯 action，无 menu、无 sendAction、无手势
        button.target = self
        button.action = #selector(openFloatingPanel)

        // ✅ 关键：完全不设置 menu

        NSLog("✅ Status bar ready: left-click only, no menu")
    }

    // 左键点击：打开/切换面板
    @objc private func openFloatingPanel() {
        toggleFloatingPanel()
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
    let copyHandler: (ClipboardItemData) -> Void

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
