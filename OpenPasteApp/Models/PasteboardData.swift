import Foundation
import AppKit

// MARK: - PasteboardData

/// Represents complete pasteboard data with all types and their corresponding data
/// Used to preserve all clipboard formats for accurate restoration
struct PasteboardData: Codable {
    /// Array of type identifiers available on the pasteboard
    let types: [String]

    /// Dictionary mapping type identifiers to their data
    /// Data is base64-encoded for JSON serialization
    let dataMap: [String: String]

    /// Initialize with pasteboard types and data dictionary
    init(types: [String], dataMap: [String: Data]) {
        // Sort types to ensure consistent hashing regardless of order
        self.types = types.sorted()
        self.dataMap = dataMap.mapValues { $0.base64EncodedString() }
    }

    /// Get data for a specific type
    func data(forType type: String) -> Data? {
        guard let base64String = dataMap[type] else { return nil }
        return Data(base64Encoded: base64String)
    }

    /// Encode to JSON data for storage
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decode from JSON data
    static func decode(from data: Data) -> PasteboardData? {
        try? JSONDecoder().decode(PasteboardData.self, from: data)
    }

    /// Get the types array as JSON string for database storage
    func encodeTypes() -> String? {
        guard let data = try? JSONEncoder().encode(types),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    /// Decode types from JSON string
    static func decodeTypes(from jsonString: String) -> [String]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}

// MARK: - PasteboardReader

/// Helper for reading all pasteboard data
struct PasteboardReader {
    /// Types to exclude from pasteboard capture (transient metadata types)
    /// These contain timestamps or other variable metadata that breaks deduplication
    private static let excludedTypes: Set<String> = [
        "org.nspasteboard.TransientType",
        "org.nspasteboard.ConsecutiveType",
        "org.nspasteboard.SourceType",
        "com.apple.pasteboard.promised-file-content-type",
        "com.apple.pasteboard.generate-clipboard-unique-id",
        "com.apple.pasteboard.board-clipboard-specific",
    ]

    /// Extract all types and data from pasteboard, excluding transient metadata types
    static func readAll(from pasteboard: NSPasteboard) -> PasteboardData? {
        guard let types = pasteboard.types else { return nil }

        // Debug: log all types before filtering
        NSLog("📋 Pasteboard types BEFORE filtering:")
        for type in types {
            let isExcluded = excludedTypes.contains(type.rawValue)
            let marker = isExcluded ? "❌ (excluded)" : "✅"
            NSLog("  \(marker) \(type.rawValue)")
        }

        // Filter out excluded types (metadata that changes on each copy)
        let filteredTypes = types.filter { !excludedTypes.contains($0.rawValue) }

        // Convert to String array
        let typeStrings = filteredTypes.map { $0.rawValue }

        var dataMap: [String: Data] = [:]

        // Read data for each filtered type
        for type in filteredTypes {
            if let data = pasteboard.data(forType: type) {
                dataMap[type.rawValue] = data
            }
        }

        // Filter out empty data and limit size
        let filteredMap = dataMap.filter { !$1.isEmpty }

        // Skip if no valid data
        guard !filteredMap.isEmpty else { return nil }

        return PasteboardData(types: typeStrings, dataMap: filteredMap)
    }
}

// MARK: - PasteboardWriter

/// Helper for writing complete pasteboard data
struct PasteboardWriter {
    /// Write all types and data to pasteboard
    static func writeAll(_ pasteboardData: PasteboardData, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        // Write each type and its data
        var writtenTypes = 0
        for type in pasteboardData.types {
            // Skip file-url types that point to other app containers (sandbox violation)
            if type == "public.file-url" {
                if let data = pasteboardData.data(forType: type),
                   let urlString = String(data: data, encoding: .utf8),
                   urlString.contains("/Library/Containers/") {
                    NSLog("⚠️ Skipping sandboxed file-url: \(urlString)")
                    continue
                }
            }

            if let data = pasteboardData.data(forType: type) {
                do {
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
                    writtenTypes += 1
                } catch {
                    NSLog("⚠️ Failed to write type \(type): \(error)")
                }
            }
        }

        NSLog("✅ Successfully wrote \(writtenTypes)/\(pasteboardData.types.count) types to pasteboard")
    }
}
