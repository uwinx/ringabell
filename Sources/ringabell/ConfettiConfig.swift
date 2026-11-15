import AppKit
import ArgumentParser
import Foundation

enum Effect: String, CaseIterable, ExpressibleByArgument {
    case confetti
    case pulse
    case none
}

enum AppIcon: String, CaseIterable, ExpressibleByArgument {
    case party
    case bell
    case sparkles
    case confetti
    case checkmark
    case star
    case rocket
    case fire

    var emoji: String {
        switch self {
        case .party:     return "🎉"
        case .bell:      return "🔔"
        case .sparkles:  return "✨"
        case .confetti:  return "🎊"
        case .checkmark: return "✅"
        case .star:      return "⭐"
        case .rocket:    return "🚀"
        case .fire:      return "🔥"
        }
    }

    func render(size: CGFloat = 256) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.8)
        ]
        let str = NSAttributedString(string: emoji, attributes: attrs)
        let strSize = str.size()
        str.draw(at: NSPoint(
            x: (size - strSize.width) / 2,
            y: (size - strSize.height) / 2
        ))
        image.unlockFocus()
        return image
    }

}

enum NotificationIcon {
    case emoji(AppIcon)
    case file(URL)

    static let fileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif"]

    func image() -> NSImage? {
        switch self {
        case .emoji(let icon): return icon.render()
        case .file(let url):   return NSImage(contentsOf: url)
        }
    }
}

struct NotificationButton {
    let id: String
    let title: String
    let action: String
}

struct ConfettiConfig {
    static let defaultColors = "red,green,blue,yellow,orange,purple"

    let title: String
    let subtitle: String
    let message: String
    let soundName: String
    let colors: [NSColor]
    let duration: Double
    let density: Double
    let effect: Effect
    let showNotification: Bool
    let respectFocus: Bool
    let url: String?
    let icon: NotificationIcon
    let context: String?
    let buttons: [NotificationButton]

    static func templateReplace(_ template: String, context json: String?) -> String {
        guard let json, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return template }

        var result = template
        let pattern = try! NSRegularExpression(pattern: #"\{\{(\w+(?:\.\w+)*)\}\}"#)
        let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let keyPath = String(result[keyRange])
            if let value = resolve(keyPath: keyPath, in: obj) {
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: value)
            }
        }
        return result
    }

    private static func resolve(keyPath: String, in obj: [String: Any]) -> String? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = obj
        for key in keys {
            guard let dict = current as? [String: Any], let next = dict[key] else { return nil }
            current = next
        }
        if let s = current as? String { return s }
        if let n = current as? NSNumber { return n.stringValue }
        return nil
    }

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
