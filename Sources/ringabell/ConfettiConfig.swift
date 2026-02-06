import AppKit

struct ConfettiConfig {
    static let defaultColors = "red,green,blue,yellow,orange,purple"

    let message: String
    let soundName: String
    let colors: [NSColor]
    let duration: Double
    let density: Double
    let showNotification: Bool
    let url: String?

    static func parseColors(_ csv: String) -> [NSColor] {
        csv.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap(parseColor)
    }

    private static func parseColor(_ name: String) -> NSColor? {
        if name.hasPrefix("#") { return hexColor(name) }
        switch name.lowercased() {
        case "red":    return .systemRed
        case "green":  return .systemGreen
        case "blue":   return .systemBlue
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "pink":   return .systemPink
        case "cyan":   return .cyan
        case "white":  return .white
        case "gold":   return NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        default:       return nil
        }
    }

    private static func hexColor(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }

        // Expand 3-char shorthand: #F0A → #FF00AA
        if h.count == 3 {
            h = h.map { "\($0)\($0)" }.joined()
        }

        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return NSColor(
            red:   CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >> 8)  & 0xFF) / 255,
            blue:  CGFloat( val        & 0xFF) / 255,
            alpha: 1
        )
    }
}
