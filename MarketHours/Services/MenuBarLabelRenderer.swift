import AppKit

/// Draws the status item: the flag and countdown alone, with tabular digits so the item
/// keeps its width as the countdown ticks. SwiftUI ignores .monospacedDigit() in a
/// MenuBarExtra label, and a Text label changed width every second (108-110 pt measured).
/// With no countdown to show (every market hidden) it draws the chart glyph instead, so
/// there is always something to click.
///
/// Not a template image, because a template would turn the flag into a solid shape. The
/// image draws itself on demand instead, in `labelColor` resolved against the appearance it
/// is drawn in, so the text stays white on a dark menu bar and black on a light one.
enum MenuBarLabelRenderer {
    @MainActor
    static func image(for text: String) -> NSImage {
        let fontSize = NSFont.menuBarFont(ofSize: 0).pointSize
        if text.isEmpty {
            return glyphImage(fontSize: fontSize)
        }
        let textSize = attributed(text, fontSize: fontSize).size()
        let size = NSSize(width: ceil(textSize.width), height: ceil(textSize.height))
        let image = NSImage(size: size, flipped: false) { _ in
            attributed(text, fontSize: fontSize).draw(at: .zero)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func glyphImage(fontSize: CGFloat) -> NSImage {
        let symbolSize = symbol(fontSize: fontSize)?.size ?? NSSize(width: fontSize, height: fontSize)
        let image = NSImage(size: symbolSize, flipped: false) { rect in
            symbol(fontSize: fontSize)?.draw(in: rect)
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
