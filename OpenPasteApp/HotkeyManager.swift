//
//  HotkeyManager.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import Foundation
import AppKit
import ApplicationServices

class HotkeyManager {
    private var eventMonitor: Any?

    var onHotkeyPressed: (() -> Void)?

    func registerHotkey() -> Bool {
        print("🔧 Registering hotkey...")

        // Check accessibility permission
        let trusted = AXIsProcessTrusted()

        print("Accessibility trusted: \(trusted)")

        if !trusted {
            // Show alert to user - make it app modal so it's visible
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "OpenPaste 需要辅助功能权限来监听全局热键 ⌘⇧V\n\n请前往：\n系统设置 → 隐私与安全性 → 辅助功能\n\n找到 OpenPaste 并打开开关"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")

                alert.beginSheetModal(for: NSApp.keyWindow!) { response in
                    if response == .alertFirstButtonReturn {
                        // Open System Settings to Accessibility
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }

            return false
        }

        // Start monitoring
        return startMonitoring()
    }

    private func startMonitoring() -> Bool {
        print("🔧 Starting global monitoring...")

        // Monitor for Command+Shift+V globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let modifiers = event.modifierFlags
            let key = event.charactersIgnoringModifiers ?? "?"

            print("🔑 Key: \(key) mods: \(modifiers.rawValue)")

            // Check for Command+Shift+V
            let isCommand = modifiers.contains(.command)
            let isShift = modifiers.contains(.shift)
            let isV = key.lowercased() == "v"

            if isCommand && isShift && isV {
                print("🔥 Hotkey triggered!")
                self.onHotkeyPressed?()
            }
        }

        if eventMonitor != nil {
            print("✅ Monitor registered successfully")
            return true
        } else {
            print("❌ Failed to register monitor")
            return false
        }
    }

    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
