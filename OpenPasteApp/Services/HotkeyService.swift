import Foundation
import AppKit
import Carbon

// MARK: - HotkeyService
/// Manages global hotkey registration using Carbon C APIs.
/// Uses EventHotKeyRef for cleanup tracking and proper error handling.
final class HotkeyService {
    // MARK: - Types

    /// Callback invoked when the hotkey is pressed
    typealias HotkeyHandler = () -> Void

    /// Errors that can occur during hotkey registration
    enum HotkeyError: Error, LocalizedError {
        case registrationFailed(OSStatus)
        case alreadyRegistered
        case invalidKeyCode

        var errorDescription: String? {
            switch self {
            case .registrationFailed(let status):
                return "Hotkey registration failed with OSStatus: \(status)"
            case .alreadyRegistered:
                return "Hotkey is already registered"
            case .invalidKeyCode:
                return "Invalid key code"
            }
        }
    }

    // MARK: - Properties

    /// Carbon Event HotKey reference for cleanup
    private var hotKeyRef: EventHotKeyRef?

    /// Keyboard shortcut modifier flags (e.g., Command, Shift)
    let modifiers: UInt32

    /// Virtual key code for the hotkey
    let keyCode: UInt32

    /// Hotkey ID for Carbon registration
    private let hotKeyID: EventHotKeyID

    /// Callback invoked when hotkey is pressed
    private let handler: HotkeyHandler

    /// Whether the hotkey is currently registered
    private(set) var isRegistered = false

    // MARK: - Initialization

    /// Initialize the hotkey service
    /// - Parameters:
    ///   - keyCode: Virtual key code (e.g., 48 for Tab, 49 for Space)
    ///   - modifiers: Modifier flags (e.g., cmdKey, shiftKey)
    ///   - handler: Callback invoked when hotkey is pressed
    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping HotkeyHandler) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler

        // Generate unique hotkey ID from signature and ID
        self.hotKeyID = EventHotKeyID(
            signature: OSType(0x48544B59), // 'HTKY' as four-char code
            id: UInt32(keyCode) << 16 | UInt32(modifiers) // Combine key and modifiers
        )

        // Register hotkey on initialization
        try? registerGlobalHotkey()
    }

    deinit {
        unregisterGlobalHotkey()
    }

    // MARK: - Public Methods

    /// Register the global hotkey using Carbon C API
    /// - Throws: HotkeyError if registration fails
    func registerGlobalHotkey() throws {
        guard !isRegistered else {
            throw HotkeyError.alreadyRegistered
        }

        // Validate key code
        guard keyCode > 0 && keyCode < 0xFF else {
            throw HotkeyError.invalidKeyCode
        }

        // Get the event target for the application
        let eventTarget = GetApplicationEventTarget()

        // Install event handler for hotkey press
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            // Invoke the handler callback
            if let context = userData {
                let hotkeyService = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
                hotkeyService.handler()
            }
            return noErr
        }

        // Retain self for the handler context
        let contextPtr = Unmanaged.passUnretained(self).toOpaque()

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            eventTarget,
            handler,
            1,
            &eventType,
            contextPtr,
            &handlerRef
        )

        guard status == noErr else {
            throw HotkeyError.registrationFailed(status)
        }

        // Register the hotkey
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            eventTarget,
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            // Clean up event handler on failure
            if let handlerRef = handlerRef {
                RemoveEventHandler(handlerRef)
            }
            throw HotkeyError.registrationFailed(hotKeyStatus)
        }

        isRegistered = true
    }

    /// Unregister the global hotkey for app termination cleanup
    func unregisterGlobalHotkey() {
        guard isRegistered, let hotKeyRef = hotKeyRef else {
            return
        }

        // Unregister the hotkey
        UnregisterEventHotKey(hotKeyRef)

        // Clear the reference
        self.hotKeyRef = nil
        isRegistered = false
    }
}
