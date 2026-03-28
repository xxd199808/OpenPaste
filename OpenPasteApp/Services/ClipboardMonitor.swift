import Foundation
import AppKit

// MARK: - ClipboardMonitor
/// Monitors the system clipboard for changes using NSPasteboard.changeCount detection.
/// Implements adaptive polling to balance responsiveness with system resources.
final class ClipboardMonitor {
    // MARK: - Types

    /// Callback invoked when new clipboard content is detected
    typealias ClipboardChangeHandler = (content: Data, contentType: String, sourceApp: String?)

    // MARK: - Properties

    /// The pasteboard being monitored
    private let pasteboard = NSPasteboard.general

    /// Last observed change count for detecting new clipboard content
    private(set) var lastChangeCount: Int

    /// Timer for periodic clipboard checks
    private var pollingTimer: Timer?

    /// Current polling interval in seconds
    private var currentPollingInterval: TimeInterval = 0.5

    /// Polling intervals for adaptive strategy (fast → medium → slow)
    private let pollingIntervals: [TimeInterval] = [0.5, 2.0, 5.0]

    /// Current adaptive level (0 = fast, 1 = medium, 2 = slow)
    private var adaptiveLevel = 0

    /// Timestamp of last user activity (for idle detection)
    private var lastActivityTimestamp: Date

    /// Idle threshold in seconds before slowing down polling
    private let idleThreshold: TimeInterval = 30.0

    /// Whether monitoring is currently active
    private(set) var isMonitoring = false

    /// Flag to skip the next clipboard change detection (used when app writes to clipboard)
    private var skipNextChangeFlag = false

    /// Callback invoked when clipboard changes are detected
    private let onChange: ((Data, String, String?) -> Void)

    // MARK: - Initialization

    /// Initialize the clipboard monitor
    /// - Parameter onChange: Callback invoked when new clipboard content is detected
    init(onChange: @escaping (Data, String, String?) -> Void) {
        self.onChange = onChange
        self.lastChangeCount = pasteboard.changeCount
        self.lastActivityTimestamp = Date()

        // Observe workspace notifications for sleep/wake
        setupWorkspaceNotifications()
    }

    deinit {
        stopMonitoring()
        removeWorkspaceNotifications()
    }

    // MARK: - Public Methods

    /// Start monitoring the clipboard for changes
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount
        lastActivityTimestamp = Date()

        // Start polling timer
        scheduleNextPoll()
    }

    /// Skip the next detected clipboard change (call before writing to pasteboard)
    func skipNextChange() {
        skipNextChangeFlag = true
    }

    /// Stop monitoring the clipboard
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Private Methods - Workspace Notifications

    private func setupWorkspaceNotifications() {
        let workspace = NSWorkspace.shared

        // Observe sleep notifications to pause monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computerWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: workspace
        )

        // Observe wake notifications to resume monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computerDidWake),
            name: NSWorkspace.didWakeNotification,
            object: workspace
        )

        // Observe screens wake notifications (e.g., from screen saver)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computerDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: workspace
        )
    }

    private func removeWorkspaceNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func computerWillSleep() {
        // Pause monitoring when computer goes to sleep
        stopMonitoring()
    }

    @objc private func computerDidWake() {
        // Resume monitoring when computer wakes up
        startMonitoring()
    }

    // MARK: - Private Methods - Adaptive Polling

    private func scheduleNextPoll() {
        guard isMonitoring else { return }

        // Invalidate existing timer
        pollingTimer?.invalidate()

        // Schedule next poll with current interval
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: currentPollingInterval,
            repeats: false
        ) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        guard isMonitoring else { return }

        // Update activity timestamp
        let now = Date()
        lastActivityTimestamp = now

        // Check for clipboard changes
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            // Skip if the app itself triggered this change
            if skipNextChangeFlag {
                skipNextChangeFlag = false
                return
            }

            // Reset to fast polling when change is detected
            adaptiveLevel = 0
            currentPollingInterval = pollingIntervals[0]

            // Extract clipboard content
            if let (content, contentType) = extractClipboardContent() {
                // Get source app
                let sourceApp = getCurrentSourceApp()

                // Notify callback
                onChange(content, contentType, sourceApp)
            }
        } else {
            // No change - check if we should slow down polling
            updateAdaptivePolling()
        }

        // Schedule next poll
        scheduleNextPoll()
    }

    private func updateAdaptivePolling() {
        let idleTime = Date().timeIntervalSince(lastActivityTimestamp)

        // Adjust polling based on idle time
        if idleTime > idleThreshold && adaptiveLevel < pollingIntervals.count - 1 {
            adaptiveLevel += 1
            currentPollingInterval = pollingIntervals[adaptiveLevel]
        } else if idleTime < idleThreshold / 2 && adaptiveLevel > 0 {
            // Speed up if activity resumes
            adaptiveLevel = max(0, adaptiveLevel - 1)
            currentPollingInterval = pollingIntervals[adaptiveLevel]
        }
    }

    // MARK: - Private Methods - Content Extraction

    private func extractClipboardContent() -> (Data, String)? {
        // Try to get string content first
        if let string = pasteboard.string(forType: .string),
           let data = string.data(using: .utf8) {
            return (data, "public.utf8-plain-text")
        }

        // Try to get image content
        if let image = pasteboard.data(forType: .tiff) {
            return (image, "public.image")
        }

        // Try to get file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let data = try? JSONEncoder().encode(fileURLs.map { $0.absoluteString }) {
            return (data, "public.file-url")
        }

        return nil
    }

    private func getCurrentSourceApp() -> String? {
        let workspace = NSWorkspace.shared

        // Get the currently active application
        if let runningApp = workspace.frontmostApplication {
            return runningApp.localizedName
        }

        return nil
    }
}
