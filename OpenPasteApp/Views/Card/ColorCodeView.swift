import SwiftUI

/// View for displaying color codes with preview and format conversion
struct ColorCodeView: View {
    let content: String

    @State private var parsedColor: ParsedColor?
    @State private var selectedFormat: ColorFormat = .hex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Color preview and primary format
            HStack(spacing: 12) {
                // Color preview square
                if let color = parsedColor {
                    Rectangle()
                        .fill(color.swiftColor)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Image(systemName: "questionmark")
                                .foregroundColor(.secondary)
                        )
                }

                // Primary color value
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedFormat.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let color = parsedColor, let formatted = color.format(selectedFormat) {
                        Text(formatted)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    } else {
                        Text(content)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                // Copy button for current format
                if let color = parsedColor, let formatted = color.format(selectedFormat) {
                    Button(action: {
                        copyToClipboard(formatted)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("复制 \(selectedFormat.displayName)")
                }
            }

            // Format selector
            if parsedColor != nil {
                HStack(spacing: 6) {
                    ForEach(ColorFormat.allCases, id: \.self) { format in
                        Button(action: {
                            selectedFormat = format
                        }) {
                            Text(format.shortName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedFormat == format ? Color.accentColor : Color.clear)
                                .foregroundColor(selectedFormat == format ? .white : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            parsedColor = ColorParser.parse(content)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - ParsedColor

struct ParsedColor {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var swiftColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func format(_ format: ColorFormat) -> String? {
        switch format {
        case .hex:
            return toHex()
        case .rgb:
            return toRGB()
        case .hsl:
            return toHSL()
        }
    }

    private func toHex() -> String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)

        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func toRGB() -> String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        if alpha < 1.0 {
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
        }
        return String(format: "rgb(%d, %d, %d)", r, g, b)
    }

    private func toHSL() -> String {
        let max = Swift.max(red, green, blue)
        let min = Swift.min(red, green, blue)
        let l = (max + min) / 2.0

        var s: Double = 0
        if l < 0.5 {
            s = (max - min) / (max + min)
        } else {
            s = (max - min) / (2.0 - max - min)
        }

        var h: Double = 0
        if max != min {
            if max == red {
                h = (green - blue) / (max - min)
                if green < blue { h += 6 }
            } else if max == green {
                h = (blue - red) / (max - min) + 2
            } else {
                h = (red - green) / (max - min) + 4
            }
        }
        h *= 60

        if alpha < 1.0 {
            return String(format: "hsla(%.0f, %.0f%%, %.0f%%, %.2f)", h, s * 100, l * 100, alpha)
        }
        return String(format: "hsl(%.0f, %.0f%%, %.0f%%)", h, s * 100, l * 100)
    }
}

// MARK: - ColorFormat

enum ColorFormat: CaseIterable {
    case hex
    case rgb
    case hsl

    var displayName: String {
        switch self {
        case .hex: return "十六进制"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        }
    }

    var shortName: String {
        switch self {
        case .hex: return "HEX"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        }
    }
}

// MARK: - ColorParser

enum ColorParser {
    static func parse(_ string: String) -> ParsedColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try hex format
        if let color = parseHex(trimmed) {
            return color
        }

        // Try RGB/RGBA format
        if let color = parseRGB(trimmed) {
            return color
        }

        // Try HSL/HSLA format
        if let color = parseHSL(trimmed) {
            return color
        }

        return nil
    }

    private static func parseHex(_ string: String) -> ParsedColor? {
        guard string.hasPrefix("#") else { return nil }
        let hex = String(string.dropFirst())

        if hex.count == 3 {
            // Expand 3-digit to 6-digit
            let expanded = hex.map { String(repeating: $0, count: 2) }.joined()
            return parseHex6(expanded)
        } else if hex.count == 6 {
            return parseHex6(hex)
        } else if hex.count == 8 {
            return parseHex8(hex)
        }

        return nil
    }

    private static func parseHex6(_ hex: String) -> ParsedColor? {
        let chars = Array(hex)
        guard chars.count == 6 else { return nil }

        guard let r1 = Int(String(chars[0]), radix: 16),
              let g1 = Int(String(chars[1]), radix: 16),
              let b1 = Int(String(chars[2]), radix: 16),
              let r2 = Int(String(chars[3]), radix: 16),
              let g2 = Int(String(chars[4]), radix: 16),
              let b2 = Int(String(chars[5]), radix: 16) else {
            return nil
        }

        let redVal = Double(r1 * 16 + r2) / 255.0
        let greenVal = Double(g1 * 16 + g2) / 255.0
        let blueVal = Double(b1 * 16 + b2) / 255.0
        return ParsedColor(red: redVal, green: greenVal, blue: blueVal, alpha: 1.0)
    }

    private static func parseHex8(_ hex: String) -> ParsedColor? {
        let chars = Array(hex)
        guard chars.count == 8 else { return nil }

        guard let r1 = Int(String(chars[0]), radix: 16),
              let g1 = Int(String(chars[1]), radix: 16),
              let b1 = Int(String(chars[2]), radix: 16),
              let a1 = Int(String(chars[3]), radix: 16),
              let r2 = Int(String(chars[4]), radix: 16),
              let g2 = Int(String(chars[5]), radix: 16),
              let b2 = Int(String(chars[6]), radix: 16),
              let a2 = Int(String(chars[7]), radix: 16) else {
            return nil
        }

        let redVal = Double(r1 * 16 + r2) / 255.0
        let greenVal = Double(g1 * 16 + g2) / 255.0
        let blueVal = Double(b1 * 16 + b2) / 255.0
        let alphaVal = Double(a1 * 16 + a2) / 255.0
        return ParsedColor(red: redVal, green: greenVal, blue: blueVal, alpha: alphaVal)
    }

    private static func parseRGB(_ string: String) -> ParsedColor? {
        let rgbPattern = #"^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$"#
        guard let regex = try? NSRegularExpression(pattern: rgbPattern),
              let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)),
              match.range.length == string.utf16.count else {
            return nil
        }

        // Extract captured groups
        let rStr: String
        if let range = match.range(at: 1, in: 0..<match.numberOfRanges),
           let temp = (string as NSString).substring(with: range) {
            rStr = temp
        } else {
            return nil
        }

        let gStr: String
        if let range = match.range(at: 2, in: 0..<match.numberOfRanges),
           let temp = (string as NSString).substring(with: range) {
            gStr = temp
        } else {
            return nil
        }

        let bStr: String
        if let range = match.range(at: 3, in: 0..<match.numberOfRanges),
           let temp = (string as NSString).substring(with: range) {
            bStr = temp
        } else {
            return nil
        }

        guard let r = Double(rStr),
              let g = Double(gStr),
              let b = Double(bStr) else {
            return nil
        }

        let alpha: Double
        if match.numberOfRanges > 4,
           let range = match.range(at: 4, in: 0..<match.numberOfRanges),
           let aStr = (string as NSString).substring(with: range),
           let a = Double(aStr) {
            alpha = a
        } else {
            alpha = 1.0
        }

        return ParsedColor(red: r/255, green: g/255, blue: b/255, alpha: alpha)
    }

    private static func parseHSL(_ string: String) -> ParsedColor? {
        let hslPattern = #"^hsla?\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*(?:,\s*([\d.]+)\s*)?\)$"#
        guard let regex = try? NSRegularExpression(pattern: hslPattern),
              let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)),
              match.range.length == string.utf16.count else {
            return nil
        }

        guard let hStr = (string as NSString).substring(with: match.range(at: 1) as? String),
              let sStr = (string as NSString).substring(with: match.range(at: 2) as? String),
              let lStr = (string as NSString).substring(with: match.range(at: 3) as? String),
              let h = Double(hStr),
              let s = Double(sStr),
              let l = Double(lStr) else {
            return nil
        }

        let alpha: Double
        if match.range(at: 4).location != NSNotFound,
           let aStr = (string as NSString).substring(with: match.range(at: 4) as? String),
           let a = Double(aStr) {
            alpha = a
        } else {
            alpha = 1.0
        }

        return ParsedColor(red: 0, green: 0, blue: 0, alpha: alpha).convertFromHSL(h: h/360, s: s/100, l: l/100)
    }
}

extension ParsedColor {
    func convertFromHSL(h: Double, s: Double, l: Double) -> ParsedColor {
        let r: Double, g: Double, b: Double

        if s == 0 {
            r = l
            g = l
            b = l
        } else {
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q

            let hk = h * 6

            func calc(_ t: Double) -> Double {
                if t < 1 { return p + (q - p) * t }
                if t < 3 { return q }
                if t < 4 { return p + (q - p) * (4 - t) }
                return p
            }

            r = calc(hk)
            g = calc(hk + 2)
            b = calc(hk + 4)
        }

        return ParsedColor(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Preview

#Preview("Color Code - Hex") {
    ColorCodeView(content: "#FF5733")
        .frame(width: 300)
        .padding()
}

#Preview("Color Code - RGB") {
    ColorCodeView(content: "rgb(255, 87, 51)")
        .frame(width: 300)
        .padding()
}

#Preview("Color Code - HSL") {
    ColorCodeView(content: "hsl(11, 100%, 60%)")
        .frame(width: 300)
        .padding()
}
