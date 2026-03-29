//
//  SimpleHotkey.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import Foundation
import AppKit
import Carbon

class SimpleHotkey {
    private var eventHandlerRef: EventHandlerRef?

    var onKeyDown: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var hotkeyRef: EventHotKeyRef?

        let hotkeyID = EventHotKeyID(signature: OSType(0x4F505354), id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(0x6B657962), eventKind: UInt32(kEventHotKeyPressed))

        // Create a pointer to self for userData
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { (handler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
            if let userData = userData {
                let hotkey = Unmanaged<SimpleHotkey>.fromOpaque(userData).takeUnretainedValue()
                hotkey.onKeyDown?()
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)

        guard installStatus == noErr else {
            print("❌ Failed to install event handler: \(installStatus)")
            return false
        }

        let hotkeyStatus = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)

        if hotkeyStatus == noErr {
            print("✅ Hotkey registered successfully")
            return true
        } else {
            print("❌ Failed to register hotkey: \(hotkeyStatus)")
            return false
        }
    }

    func unregister() {
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }
}
