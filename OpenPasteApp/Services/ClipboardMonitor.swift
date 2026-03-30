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

    /// Counter to skip the next clipboard change detection (used when app writes to clipboard)
    private var skipNextChangesCount: Int = 0

    /// Callback invoked when clipboard changes are detected
    private let onChange: ((Data, String, String?, String?) -> Void)

    // MARK: - Initialization

    /// Initialize the clipboard monitor
    /// - Parameter onChange: Callback invoked when new clipboard content is detected (content, contentType, sourceApp, title)
    init(onChange: @escaping (Data, String, String?, String?) -> Void) {
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
        skipNextChangesCount = 1  // Skip only one change since a single write increments changeCount once
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
            // Skip if the app itself triggered this change
            if skipNextChangesCount > 0 {
                skipNextChangesCount -= 1
                lastChangeCount = currentChangeCount
                // Do NOT return here — must schedule next poll!
            } else {
                // Update lastChangeCount
                lastChangeCount = currentChangeCount

                // Reset to fast polling when change is detected
                adaptiveLevel = 0
                currentPollingInterval = pollingIntervals[0]

                // Extract clipboard content
                if let (content, contentType, title) = extractClipboardContent() {
                    // Play notification sound for new content
                    playNotificationSound()

                    // Get source app
                    let sourceApp = getCurrentSourceApp()

                    // Notify callback with content, type, source app, and title
                    onChange(content, contentType, sourceApp, title)
                }
            }
        } else {
            // No change - check if we should slow down polling
            updateAdaptivePolling()
        }

        // Always schedule next poll
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

    private func extractClipboardContent() -> (Data, String, String?)? {
        // Try to get file URLs FIRST (to capture folders before their icon images)
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !fileURLs.isEmpty,
           fileURLs.allSatisfy({ $0.isFileURL }) {

            // Check if any URL is a directory (folder)
            let isDirectory = fileURLs.contains { url in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }

            let contentType = isDirectory ? "public.folder" : "public.file-url"
            if let data = try? JSONEncoder().encode(fileURLs.map { $0.absoluteString }) {
                return (data, contentType, nil)
            }
        }

        // Try to get rich link data (from mobile apps sharing)
        if let richLinkData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.rich-link")),
           let (content, contentType, title) = parseRichLinkData(richLinkData) {
            // Store title temporarily to pass with callback
            return (content, contentType, title)
        }

        // Try to get URL (web links) using .url type
        if let urlString = pasteboard.string(forType: NSPasteboard.PasteboardType.URL),
           !urlString.isEmpty,
           let data = urlString.data(using: .utf8) {
            return (data, "public.url", nil)
        }

        // Try to get image content — return raw data, defer file saving to ViewModel
        if let imageData = pasteboard.data(forType: .tiff) {
            return (imageData, "public.image", nil)
        }

        // Try to get string content (check last to avoid capturing folder paths as text)
        if let string = pasteboard.string(forType: .string),
           !string.isEmpty,
           let data = string.data(using: .utf8) {

            // Check if the string is a pure URL (no extra text around it)
            if isPureURL(string) {
                return (data, "public.url", nil)
            }

            return (data, "public.utf8-plain-text", nil)
        }

        return nil
    }

    /// Parse rich link data from mobile apps (e.g., WeChat, Toutiao)
    /// Returns (content, contentType, title) tuple with extracted URL and title
    private func parseRichLinkData(_ data: Data) -> (Data, String, String?)? {
        // Try to parse as Property List
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            // Extract title and URL from rich link data
            var urlString: String?
            var title: String?
            var icon: Data?

            if let url = plist["url"] as? String {
                urlString = url
            }
            if let t = plist["title"] as? String {
                title = t
            }
            if let imageData = plist["icon"] as? Data {
                icon = imageData
            }

            // If we have a URL, store it as content with title metadata
            if let urlString = urlString,
               let contentData = urlString.data(using: .utf8) {
                // Return content, type, and extracted title
                return (contentData, "public.rich-link", title)
            }
        }

        return nil
    }

    /// Check if a string is a pure URL (no surrounding text)
    private func isPureURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pure URL pattern: starts with http://, https://, or www.
        // and contains no spaces or mixed text
        let urlPattern = #"^(https?://|www\.)[^\s]+$"#
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
           let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
            return match.range.length == trimmed.utf16.count
        }

        return false
    }

    private func getCurrentSourceApp() -> String? {
        let workspace = NSWorkspace.shared

        // Check if this appears to be iCloud-synced content
        if isICloudSyncedContent() {
            return "com.apple.icloud.clipboard"  // Special identifier for iCloud synced content
        }

        // Get the currently active application
        if let runningApp = workspace.frontmostApplication {
            // Return bundle identifier for icon loading
            return runningApp.bundleIdentifier ?? runningApp.localizedName
        }

        return nil
    }

    /// Detect if clipboard content appears to be from iCloud sync
    /// Uses heuristics: iCloud sync typically doesn't include source app metadata
    /// and the frontmost app is often a development tool or system app
    private func isICloudSyncedContent() -> Bool {
        guard let runningApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = runningApp.bundleIdentifier else {
            return false
        }

        // Check if frontmost app is commonly active when receiving iCloud synced content
        let suspectApps = [
            "com.apple.Xcode",           // Xcode
            "com.apple.dt.Xcode",        // Xcode alternative
            "com.apple.simulator",       // iOS Simulator
            "com.riotgames.leagueoflegends",  // Games (often idle)
            "com.spotify.client",        // Spotify (commonly in background)
            "com.apple.Music",           // Apple Music
            "com.apple.TV",              // Apple TV
        ]

        // If frontmost app is in suspect list, likely iCloud sync
        if suspectApps.contains(bundleId) {
            return true
        }

        // Additional heuristic: check pasteboard for lack of source app metadata
        // Local copy operations usually have more metadata
        let types = pasteboard.types ?? []
        let hasComplexMetadata = types.count > 2  // iCloud sync usually has minimal types

        return !hasComplexMetadata && isSuspectAppBundle(bundleId)
    }

    /// Check if bundle ID belongs to an app category that's commonly not the source
    private func isSuspectAppBundle(_ bundleId: String) -> Bool {
        // Development tools
        if bundleId.contains("xcode") || bundleId.contains("developer") {
            return true
        }
        // Games and entertainment
        if bundleId.contains("game") || bundleId.contains("riot") {
            return true
        }
        // Media apps
        if bundleId.contains("music") || bundleId.contains("spotify") {
            return true
        }

        return false
    }

    /// Play notification sound when new clipboard content is detected
    private func playNotificationSound() {
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.play()
        }
    }
}
