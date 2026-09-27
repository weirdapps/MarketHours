import AppKit

/// Draws the status item as one template image: the chart glyph and the countdown
/// with tabular digits. A SwiftUI Text in a MenuBarExtra label ignores
/// .monospacedDigit(), so the item changed width every second (108-110 pt measured).
enum MenuBarLabelRenderer {
    @MainActor
    static func image(for text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        let textSize = string.size()
        let symbol = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular))
        let symbolSize = symbol?.size ?? .zero
        let gap: CGFloat = text.isEmpty ? 0 : 4
        let size = NSSize(
            width: ceil(symbolSize.width + gap + textSize.width),
            height: ceil(max(textSize.height, symbolSize.height)))

        let scale: CGFloat = 2
        guard size.width > 0, size.height > 0,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return NSImage() }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        symbol?.draw(in: NSRect(
            x: 0, y: (size.height - symbolSize.height) / 2, width: symbolSize.width, height: symbolSize.height))
        string.draw(at: NSPoint(x: symbolSize.width + gap, y: (size.height - textSize.height) / 2))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        image.isTemplate = true
        return image
    }
}
