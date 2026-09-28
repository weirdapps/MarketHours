import AppKit

/// Draws the status item: the chart glyph and the countdown, with tabular digits so the
/// item keeps its width as the countdown ticks. SwiftUI ignores .monospacedDigit() in a
/// MenuBarExtra label, and a Text label changed width every second (108-110 pt measured).
///
/// Not a template image, because a template would turn the flag into a solid shape. The
/// image draws itself on demand instead, in `labelColor` resolved against the appearance it
/// is drawn in, so the text stays white on a dark menu bar and black on a light one.
enum MenuBarLabelRenderer {
    @MainActor
    static func image(for text: String) -> NSImage {
        let fontSize = NSFont.menuBarFont(ofSize: 0).pointSize
        let textSize = attributed(text, fontSize: fontSize).size()
        let symbolSize = symbol(fontSize: fontSize)?.size ?? .zero
        let gap: CGFloat = text.isEmpty ? 0 : 4
        let size = NSSize(
            width: ceil(symbolSize.width + gap + textSize.width),
            height: ceil(max(textSize.height, symbolSize.height)))
        let image = NSImage(size: size, flipped: false) { _ in
            if let symbol = symbol(fontSize: fontSize) {
                symbol.draw(in: NSRect(
                    x: 0, y: (size.height - symbolSize.height) / 2,
                    width: symbolSize.width, height: symbolSize.height))
            }
            attributed(text, fontSize: fontSize)
                .draw(at: NSPoint(x: symbolSize.width + gap, y: (size.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func attributed(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    private static func symbol(fontSize: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
            // One colour per layer: with a single palette colour the axis layer draws dimmer.
            .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor, .labelColor, .labelColor]))
        return NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}
