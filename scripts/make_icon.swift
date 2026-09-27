// Draws the app icon at every size macOS asks for and rewrites the asset catalog.
//
//     swift scripts/make_icon.swift
//
// A blue-to-cyan rounded square, matching the panel header, with the white
// chart.line.uptrend.xyaxis symbol. Output: MarketHours/Assets.xcassets/AppIcon.appiconset.

import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconSet = root.appendingPathComponent("MarketHours/Assets.xcassets/AppIcon.appiconset")

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let side = CGFloat(pixels)
    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Apple's macOS grid: an 824 pt body centred on a 1024 pt canvas.
    let scale = side / 1024
    let body = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.shadowBlurRadius = 24 * scale
    shadow.set()
    NSColor(calibratedRed: 0.04, green: 0.44, blue: 0.95, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.47, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.90, alpha: 1),
    ])!
    gradient.draw(in: shape, angle: -45)

    let config = NSImage.SymbolConfiguration(pointSize: 470 * scale, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        symbol.draw(in: NSRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

struct Slot {
    let points: Int
    let scale: Int
    var filename: String { "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png" }
}

let slots = [16, 32, 128, 256, 512].flatMap { [Slot(points: $0, scale: 1), Slot(points: $0, scale: 2)] }
var images: [[String: String]] = []
for slot in slots {
    try render(pixels: slot.points * slot.scale).write(to: iconSet.appendingPathComponent(slot.filename))
    images.append([
        "filename": slot.filename, "idiom": "mac",
        "scale": "\(slot.scale)x", "size": "\(slot.points)x\(slot.points)",
    ])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconSet.appendingPathComponent("Contents.json"))
print("wrote \(slots.count) icons to \(iconSet.path)")
