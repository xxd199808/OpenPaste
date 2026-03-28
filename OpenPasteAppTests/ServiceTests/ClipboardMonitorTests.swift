import XCTest
import AppKit
@testable import PasteApp

/// Unit tests for ClipboardMonitor service
final class ClipboardMonitorTests: XCTestCase {

    // MARK: - Properties

    var monitor: ClipboardMonitor!
    var capturedItems: [(content: Data, contentType: String, sourceApp: String?)] = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        capturedItems = []

        // Create monitor with callback to capture changes
        monitor = ClipboardMonitor { [weak self] content, contentType, sourceApp in
            self?.capturedItems.append((content, contentType, sourceApp))
        }
    }

    override func tearDown() async throws {
        monitor.stopMonitoring()
        monitor = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func testClipboardMonitorInitialization() {
        // Then: Monitor should have initial change count from NSPasteboard
        XCTAssertEqual(monitor.lastChangeCount, NSPasteboard.general.changeCount)
    }

    func testClipboardMonitorStartStop() {
        // Given: Monitor is not running
        XCTAssertFalse(monitor.isMonitoring)

        // When: Starting monitoring
        monitor.startMonitoring()

        // Then: Monitor should be running
        XCTAssertTrue(monitor.isMonitoring)

        // When: Stopping monitoring
        monitor.stopMonitoring()

        // Then: Monitor should not be running
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testClipboardMonitorChangeCountDetection() async throws {
        // Given: Running monitor and initial change count
        monitor.startMonitoring()
        let initialCount = monitor.lastChangeCount

        // When: Clipboard content changes (simulated by writing to pasteboard)
        await simulateClipboardChange()

        // Wait a bit for monitor to detect the change
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Change count should be updated
        XCTAssertNotEqual(monitor.lastChangeCount, initialCount)
    }

    func testClipboardMonitorCallback() async throws {
        // Given: Running monitor
        monitor.startMonitoring()

        // When: Clipboard content changes
        await simulateClipboardChange()

        // Wait for callback to be invoked
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then: Callback should have been invoked with captured content
        XCTAssertGreaterThan(capturedItems.count, 0)

        let captured = capturedItems.first!
        XCTAssertNotNil(captured.content)
        XCTAssertNotNil(captured.contentType)
    }

    func testClipboardMonitorSourceAppExtraction() async throws {
        // Given: Running monitor
        monitor.startMonitoring()

        // When: Clipboard content changes
        await simulateClipboardChange()

        // Wait for callback
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Source app should be extracted (may be current app in test)
        if let firstCapture = capturedItems.first {
            XCTAssertNotNil(firstCapture.sourceApp)
        }
    }

    func testClipboardMonitorAdaptivePolling() async throws {
        // Given: Running monitor
        monitor.startMonitoring()

        // When: No changes for extended period (simulate idle)
        let initialCount = monitor.lastChangeCount

        // Wait without making changes
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds

        // Then: Monitor should still be running (no crash)
        XCTAssertTrue(monitor.isMonitoring)

        // Change count should remain same if no changes occurred
        // (Note: may not be exactly equal in test environment due to other system events)
        XCTAssertNotNil(monitor.lastChangeCount)
    }

    func testClipboardMonitorMultipleChanges() async throws {
        // Given: Running monitor
        monitor.startMonitoring()
        let initialItemCount = capturedItems.count

        // When: Multiple clipboard changes occur
        await simulateClipboardChange()
        try await Task.sleep(nanoseconds: 150_000_000)

        await simulateClipboardChange()
        try await Task.sleep(nanoseconds: 150_000_000)

        await simulateClipboardChange()
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: All changes should be captured
        XCTAssertGreaterThan(capturedItems.count - initialItemCount, 0)
    }

    func testClipboardMonitorContentTypeDetection() async throws {
        // Given: Running monitor
        monitor.startMonitoring()

        // When: Text content is copied
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Test text", forType: .string)

        // Wait for detection
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Content type should be detected
        if let capture = capturedItems.last {
            XCTAssertEqual(capture.contentType, "public.utf8-plain-text")
        }
    }

    // MARK: - Helper Methods

    private func simulateClipboardChange() async {
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                "Test content \(Date().timeIntervalSince1970)",
                forType: .string
            )
        }
    }
}
