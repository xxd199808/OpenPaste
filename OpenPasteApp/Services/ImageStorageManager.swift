import Foundation
import AppKit
import CryptoKit

/// Manages storage of clipboard images as files in the application support directory
/// instead of storing binary data directly in Core Data
final class ImageStorageManager {
    // MARK: - Singleton

    static let shared = ImageStorageManager()

    // MARK: - Properties

    /// Directory where image files are stored
    private let imagesDirectory: URL

    /// File manager for directory operations
    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init() {
        // Get the application support directory
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // Create OpenPaste directory if needed
        let openPasteDir = appSupportURL.appendingPathComponent("OpenPaste")
        try? fileManager.createDirectory(at: openPasteDir, withIntermediateDirectories: true)

        // Create images subdirectory
        self.imagesDirectory = openPasteDir.appendingPathComponent("images")

        // Ensure images directory exists
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        NSLog("✅ ImageStorageManager initialized with directory: \(imagesDirectory.path)")
    }

    // MARK: - Public Methods

    /// Save image data to a file and return the file URL as JSON array
    /// - Parameter imageData: The raw image data (TIFF format from pasteboard)
    /// - Returns: JSON-encoded array of file URLs, or nil if save failed
    func saveImage(_ imageData: Data) -> Data? {
        // Use content hash as filename to avoid duplicate files
        let hash = SHA256.hash(data: imageData).compactMap { String(format: "%02x", $0) }.joined()
        let filename = hash + ".tiff"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        // Skip write if file already exists (same content)
        if !fileManager.fileExists(atPath: fileURL.path) {
            do {
                try imageData.write(to: fileURL)
                NSLog("✅ Saved image to: \(fileURL.path)")
            } catch {
                NSLog("❌ Failed to save image: \(error.localizedDescription)")
                return nil
            }
        }

        // Return JSON array with file URL (matches file-url format)
        let urlArray = [fileURL.absoluteString]
        return try? JSONEncoder().encode(urlArray)
    }

    /// Load image data from a file URL
    /// - Parameter urlString: The file URL string
    /// - Returns: Image data if successful, nil otherwise
    func loadImage(from urlString: String) -> Data? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            return try Data(contentsOf: url)
        } catch {
            NSLog("❌ Failed to load image from \(urlString): \(error.localizedDescription)")
            return nil
        }
    }

    /// Delete image file at the given URL
    /// - Parameter urlString: The file URL string
    func deleteImage(at urlString: String) {
        guard let url = URL(string: urlString) else { return }

        do {
            try fileManager.removeItem(at: url)
            NSLog("✅ Deleted image at: \(urlString)")
        } catch {
            // Log but don't crash if file doesn't exist
            NSLog("⚠️ Failed to delete image at \(urlString): \(error.localizedDescription)")
        }
    }
}
