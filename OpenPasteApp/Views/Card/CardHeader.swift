import SwiftUI
import AppKit

/// Card header displaying app icon, type title, timestamp, and category button
struct CardHeader: View {
    let contentType: String
    let sourceApp: String?
    let capturedAt: Date
    let categoryId: UUID?
    let title: String?
    var onCategorySelect: ((UUID?) -> Void)?
    var onTitleChange: ((String) -> Void)?

    @State private var appIcon: NSImage?
    @State private var dominantColor: Color = .clear
    @State private var fallbackAppIcon: NSImage?
    @State private var showingCategoryMenu = false
    @State private var isEditingTitle = false
    @State private var editingTitle = ""

    @State private var availableCategories: [CategoryData] = []

    /// Special identifier for iCloud synced content
    private let iCloudSyncIdentifier = "com.apple.icloud.clipboard"

    /// Whether this content appears to be from iCloud sync
    private var isICloudSynced: Bool {
        sourceApp == iCloudSyncIdentifier
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left side: App icon (overflowing left only)
            appIconView

            // Right side: title + timestamp
            VStack(alignment: .leading, spacing: 2) {
                if isEditingTitle {
                    TextField("", text: $editingTitle)
                        .font(.system(size: 15, weight: .bold))
                        .textFieldStyle(.plain)
                        .onSubmit {
                            onTitleChange?(editingTitle)
                            isEditingTitle = false
                        }
                        .onAppear {
                            editingTitle = title ?? typeTitle
                        }
                } else {
                    Text(title ?? typeTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .onTapGesture(count: 2) {
                            editingTitle = title ?? typeTitle
                            isEditingTitle = true
                        }
                }

                // Timestamp (below title, smaller)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(capturedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }

            Spacer()

            // Right side: Category/Favorite button
            categoryButton
        }
        .frame(height: 40)  // Fixed height for header area
        .padding(.horizontal, 12)
        .clipped()  // Clip vertical overflow
        .background(dominantColor)
        .onAppear {
            // Load fallback app icon (our own app's icon)
            loadFallbackAppIcon()

            if let sourceApp = sourceApp {
                loadAppIcon(for: sourceApp)
                loadDominantColor(for: sourceApp)
            }
            loadCategories()
        }
        .confirmationDialog(
            "Select Category",
            isPresented: $showingCategoryMenu,
            titleVisibility: .hidden
        ) {
            Button("Uncategorized") {
                onCategorySelect?(nil)
            }
            ForEach(availableCategories) { category in
                Button(category.name) {
                    onCategorySelect?(category.id)
                }
            }
        }
    }

    // MARK: - App Icon View

    private var appIconView: some View {
        Group {
            if isICloudSynced {
                // Show iCloud sync icon
                Image(systemName: "icloud")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(x: -20, y: 0)
            } else if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(x: -20, y: 0)
            } else {
                // Show unified cloud icon for no app icon
                Image(systemName: "icloud")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .offset(x: -20, y: 0)
            }
        }
    }

    @ViewBuilder
    private var iconBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Type Title

    private var typeTitle: String {
        switch contentType {
        case "public.utf8-plain-text", "public.text":
            return "文本"
        case "public.image", "public.tiff", "public.png":
            return "图片"
        case "public.folder":
            return "文件夹"
        case "public.file-url":
            return "文件"
        case "public.url":
            return "链接"
        case "public.email":
            return "邮箱"
        case "public.phone-number":
            return "电话"
        case "public.color-code":
            return "颜色"
        default:
            return "内容"
        }
    }

    // MARK: - Category Button

    private var categoryButton: some View {
        Button {
            showingCategoryMenu = true
        } label: {
            Image(systemName: categoryId != nil ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundColor(categoryTintColor)
        }
        .buttonStyle(.plain)
    }

    private var categoryTintColor: Color {
        guard let categoryId = categoryId else {
            return .secondary.opacity(0.6)
        }

        // Find category color
        if let category = availableCategories.first(where: { $0.id == categoryId }) {
            return colorForCategory(category)
        }

        return .accentColor
    }

    private func colorForCategory(_ category: CategoryData) -> Color {
        // Generate color based on category name hash for consistency
        let hash = category.name.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }

    // MARK: - Helper Methods

    private func loadAppIcon(for appName: String) {
        // Try bundle identifier first
        if #available(macOS 13.0, *) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
                appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                return
            }
        }

        // Try by app name using LSCopyApplicationURLsForBundleIdentifier
        if let appUrls = LSCopyApplicationURLsForBundleIdentifier(appName as CFString, nil)?.takeRetainedValue() as? [URL],
           let url = appUrls.first {
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    private func loadFallbackAppIcon() {
        // Try to load our app's icon as fallback
        if let appIcon = NSImage(named: "AppIcon") {
            fallbackAppIcon = appIcon
        }
    }

    private func loadDominantColor(for appName: String) {
        Task { @MainActor in
            // Use iCloud brand color for synced content or when no app icon
            if appName == iCloudSyncIdentifier || appIcon == nil {
                dominantColor = Color.blue.opacity(0.15)
                return
            }

            let extractedColor = await AppIconColorExtractor.shared.extractColor(for: appName)
            // Adjust brightness if too high (for white text readability)
            dominantColor = adjustBrightnessIfNeeded(extractedColor)
        }
    }

    /// Adjust color brightness if it's too high for white text readability
    private func adjustBrightnessIfNeeded(_ color: Color) -> Color {
        // Extract RGB components from SwiftUI Color
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return color
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // If brightness is too high (>0.7), darken it and increase saturation
        if brightness > 0.7 {
            brightness = 0.55  // Reduce to 55%
            saturation = min(saturation * 1.3, 1.0)  // Increase saturation by 30%
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }

        return color
        #else
        return color
        #endif
    }

    private func loadCategories() {
        // TODO: Load from ViewModel - for now use empty array
        // This will be connected to the actual category system
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        CardHeader(
            contentType: "public.utf8-plain-text",
            sourceApp: "Safari",
            capturedAt: Date().addingTimeInterval(-300),
            categoryId: nil,
            title: nil,
            onTitleChange: { _ in }
        )

        CardHeader(
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            categoryId: UUID(),
            title: "我的照片",
            onTitleChange: { _ in }
        )
    }
    .frame(width: 300)
}
