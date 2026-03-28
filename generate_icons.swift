#!/usr/bin/swift

import AppKit
import Foundation

/// 生成应用图标和菜单栏图标
class IconGenerator {

    /// 生成应用图标
    func generateAppIcon(size: CGFloat) -> NSImage {
        // 使用指定像素尺寸创建图像，避免 Retina 缩放
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

        // 确保图像以指定尺寸保存（不受 Retina 影响）
        let imageData = image.tiffRepresentation
        let bitmap = NSBitmapImageRep(data: imageData!)
        let finalImage = NSImage(size: NSSize(width: size, height: size))
        finalImage.addRepresentation(bitmap!)

        return finalImage
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

    /// 生成 SVG 格式的状态栏图标
    func generateStatusBarSVG(size: CGFloat = 16) -> String {
        // 基于 generateStatusBarIcon 的相同算法
        let padding = size * 0.1
        let iconSize = size - padding * 2
        let iconX = padding
        let iconY = padding

        // 圆角半径
        let cornerRadius = iconSize * 0.1

        // 夹子尺寸
        let clipWidth = iconSize * 0.4
        let clipHeight = iconSize * 0.15
        let clipX = iconX + (iconSize - clipWidth) / 2
        // SVG Y 轴从上到下，Swift 从下到上，需要翻转
        let clipY = padding  // 夹子在最顶部

        // 线条参数
        let lineWidth = iconSize * 0.6
        let lineHeight = iconSize * 0.04
        let lineX = iconX + (iconSize - lineWidth) / 2

        // SVG 内容
        var svg = """
        <svg width="\(Int(size))" height="\(Int(size))" viewBox="0 0 \(Int(size)) \(Int(size))" xmlns="http://www.w3.org/2000/svg">
          <!-- 剪贴板主体描边 -->
          <rect x="\(iconX)" y="\(iconY)" width="\(iconSize)" height="\(iconSize)" rx="\(cornerRadius)" ry="\(cornerRadius)"
                fill="none" stroke="currentColor" stroke-width="1"/>

          <!-- 剪贴板顶部夹子 -->
          <rect x="\(clipX)" y="\(clipY)" width="\(clipWidth)" height="\(clipHeight)" rx="\(clipHeight * 0.3)" ry="\(clipHeight * 0.3)"
                fill="currentColor"/>

          <!-- 剪贴板上的线条 -->
        """

        // 生成三条线
        let lineStartY = iconY + iconSize * 0.25
        let lineSpacing = iconSize * 0.15

        for i in 0..<3 {
            let lineY = lineStartY + CGFloat(i) * lineSpacing
            svg += """
              <rect x="\(lineX)" y="\(lineY)" width="\(lineWidth)" height="\(lineHeight)" rx="\(lineHeight / 2)" ry="\(lineHeight / 2)"
                    fill="currentColor"/>
            """
        }

        svg += """
        </svg>
        """

        return svg
    }

    /// 保存图像为 PNG
    func saveImage(_ image: NSImage, to path: String, targetSize: CGFloat? = nil) {
        // 获取图像的实际位图表示
        var bitmap: NSBitmapImageRep?

        if let targetSize = targetSize {
            // 如果指定了目标尺寸，创建指定位图
            bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(targetSize),
                pixelsHigh: Int(targetSize),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: NSColorSpaceName.deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )

            // 绘制到位图
            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext(bitmapImageRep: bitmap!)
            NSGraphicsContext.current = context
            image.draw(
                in: NSRect(x: 0, y: 0, width: targetSize, height: targetSize),
                from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
                operation: .copy,
                fraction: 1.0
            )
            NSGraphicsContext.restoreGraphicsState()
        } else {
            // 使用原始图像的位图
            guard let tiffData = image.tiffRepresentation else {
                print("❌ Failed to get TIFF data for \(path)")
                return
            }
            bitmap = NSBitmapImageRep(data: tiffData)
        }

        guard let finalBitmap = bitmap,
              let pngData = finalBitmap.representation(using: .png, properties: [:]) else {
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

    /// 保存 SVG 文件
    func saveSVG(_ svgContent: String, to path: String) {
        do {
            try svgContent.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
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
    generator.saveImage(icon, to: path, targetSize: item.size)
}

// 生成菜单栏 PNG 图标
print("\n🎨 Generating Status Bar Icons (PNG)...")
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
    generator.saveImage(icon, to: path, targetSize: item.size)
}

// 生成菜单栏 SVG 图标
print("\n🎨 Generating Status Bar Icon (SVG)...")
let svgContent = generator.generateStatusBarSVG()
let svgPath = "\(assetsPath)/StatusBarIcon.imageset/StatusBarIcon.svg"
generator.saveSVG(svgContent, to: svgPath)

// 生成 SVG 的 Contents.json
print("\n📝 Generating SVG Contents.json...")
let svgContentsJson = """
{
  "images" : [
    {
      "filename" : "StatusBarIcon.svg",
      "idiom" : "mac"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
"""
let contentsPath = "\(assetsPath)/StatusBarIcon.imageset/Contents.json"
do {
    try svgContentsJson.write(to: URL(fileURLWithPath: contentsPath), atomically: true, encoding: .utf8)
    print("✅ Saved: \(contentsPath)")
} catch {
    print("❌ Failed to save \(contentsPath): \(error)")
}

print("\n✨ Icon generation complete!")
print("\n💡 Note: To use the SVG icon, delete the PNG files from StatusBarIcon.imageset/")
