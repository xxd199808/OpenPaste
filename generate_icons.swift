#!/usr/bin/swift

import AppKit
import Foundation

/// 生成应用图标和菜单栏图标
class IconGenerator {
    
    /// 生成应用图标
    func generateAppIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        
        // 背景渐变
        let gradient = NSGradient(colors: [
            NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.4, green: 0.2, blue: 0.9, alpha: 1.0)
        ])
        
        // 绘制圆角矩形背景
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = size * 0.2
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        gradient?.draw(in: path, angle: 45)
        
        // 绘制剪贴板图标
        let iconSize = size * 0.6
        let iconX = (size - iconSize) / 2
        let iconY = (size - iconSize) / 2
        
        // 绘制剪贴板主体
        let clipboardRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        let clipboardPath = NSBezierPath(roundedRect: clipboardRect, xRadius: iconSize * 0.1, yRadius: iconSize * 0.1)
        NSColor.white.withAlphaComponent(0.95).setFill()
        clipboardPath.fill()
        
        // 绘制剪贴板顶部夹子
        let clipWidth = iconSize * 0.4
        let clipHeight = iconSize * 0.15
        let clipX = iconX + (iconSize - clipWidth) / 2
        let clipY = iconY + iconSize - clipHeight / 2
        let clipRect = NSRect(x: clipX, y: clipY, width: clipWidth, height: clipHeight)
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipHeight * 0.3, yRadius: clipHeight * 0.3)
        NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0).setFill()
        clipPath.fill()
        
        // 绘制剪贴板上的线条
        let lineColor = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
        let lineWidth = iconSize * 0.6
        let lineHeight = iconSize * 0.04
        let lineX = iconX + (iconSize - lineWidth) / 2
        
        for i in 0..<3 {
            let lineY = iconY + iconSize * 0.25 + CGFloat(i) * iconSize * 0.15
            let lineRect = NSRect(x: lineX, y: lineY, width: lineWidth, height: lineHeight)
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: lineHeight / 2, yRadius: lineHeight / 2)
            lineColor.setFill()
            linePath.fill()
        }
        
        image.unlockFocus()
        
        return image
    }
    
    /// 生成菜单栏图标（模板图像）
    func generateStatusBarIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        
        // 绘制剪贴板图标（黑色，用于模板图像）
        NSColor.black.setFill()
        
        // 绘制剪贴板主体
        let padding = size * 0.1
        let iconSize = size - padding * 2
        let iconX = padding
        let iconY = padding
        
        let clipboardRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        let clipboardPath = NSBezierPath(roundedRect: clipboardRect, xRadius: iconSize * 0.1, yRadius: iconSize * 0.1)
        clipboardPath.stroke()
        
        // 绘制剪贴板顶部夹子
        let clipWidth = iconSize * 0.4
        let clipHeight = iconSize * 0.15
        let clipX = iconX + (iconSize - clipWidth) / 2
        let clipY = iconY + iconSize - clipHeight / 2
        let clipRect = NSRect(x: clipX, y: clipY, width: clipWidth, height: clipHeight)
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipHeight * 0.3, yRadius: clipHeight * 0.3)
        clipPath.fill()
        
        // 绘制剪贴板上的线条
        let lineWidth = iconSize * 0.6
        let lineHeight = iconSize * 0.04
        let lineX = iconX + (iconSize - lineWidth) / 2
        
        for i in 0..<3 {
            let lineY = iconY + iconSize * 0.25 + CGFloat(i) * iconSize * 0.15
            let lineRect = NSRect(x: lineX, y: lineY, width: lineWidth, height: lineHeight)
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: lineHeight / 2, yRadius: lineHeight / 2)
            linePath.fill()
        }
        
        image.unlockFocus()
        
        // 设置为模板图像（自动适应深色/浅色模式）
        image.isTemplate = true
        
        return image
    }
    
    /// 保存图像为 PNG
    func saveImage(_ image: NSImage, to path: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("❌ Failed to create PNG data for \(path)")
            return
        }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            print("✅ Saved: \(path)")
        } catch {
            print("❌ Failed to save \(path): \(error)")
        }
    }
}

// 主程序
let generator = IconGenerator()
let assetsPath = "OpenPasteApp/Resources/Assets.xcassets"

// 生成应用图标
print("🎨 Generating App Icons...")
let appIconSizes: [(size: CGFloat, filename: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for item in appIconSizes {
    let icon = generator.generateAppIcon(size: item.size)
    let path = "\(assetsPath)/AppIcon.appiconset/\(item.filename)"
    generator.saveImage(icon, to: path)
}

// 生成菜单栏图标
print("\n🎨 Generating Status Bar Icons...")
let statusBarSizes: [(size: CGFloat, filename: String)] = [
    (16, "StatusBarIcon_16x16.png"),
    (32, "StatusBarIcon_16x16@2x.png"),
    (18, "StatusBarIcon_18x18.png"),
    (36, "StatusBarIcon_18x18@2x.png"),
    (22, "StatusBarIcon_22x22.png"),
    (44, "StatusBarIcon_22x22@2x.png")
]

for item in statusBarSizes {
    let icon = generator.generateStatusBarIcon(size: item.size)
    let path = "\(assetsPath)/StatusBarIcon.imageset/\(item.filename)"
    generator.saveImage(icon, to: path)
}

print("\n✨ Icon generation complete!")
