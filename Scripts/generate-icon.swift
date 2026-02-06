#!/usr/bin/env swift
import AppKit

let emoji = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "🎉"
let outputDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "."

let iconsetPath = "\(outputDir)/AppIcon.iconset"
let icnsPath = "\(outputDir)/AppIcon.icns"

try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (px, name) in sizes {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Dark background (#1C1C1E)
    NSColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: px, height: px)).fill()

    let font = NSFont.systemFont(ofSize: CGFloat(px) * 0.65)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: emoji, attributes: attrs)
    let strSize = str.size()
    str.draw(at: NSPoint(
        x: (CGFloat(px) - strSize.width) / 2,
        y: (CGFloat(px) - strSize.height) / 2
    ))

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
try task.run()
task.waitUntilExit()

try? FileManager.default.removeItem(atPath: iconsetPath)

if task.terminationStatus == 0 {
    print("Generated \(icnsPath)")
} else {
    fputs("Failed to generate icns\n", stderr)
    exit(1)
}
