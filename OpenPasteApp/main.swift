//
//  main.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import Cocoa

// Write startup log
let logPath = "/tmp/openpaste_main.log"
FileManager.default.createFile(atPath: logPath, contents: "🚀 main.swift started\n".data(using: .utf8), attributes: nil)

// Create app delegate
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// Set activation policy
app.setActivationPolicy(.regular)

// Run the app
NSLog("About to call app.run()")
app.run()
