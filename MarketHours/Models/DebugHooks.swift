#if DEBUG
import AppKit
import SwiftUI

/// Test switches for debug builds only.
///
/// `-MHShowSettings` opens the panel on its settings page.
/// `-MHWindowTest` hosts the panel in an ordinary window, shows it for 5 s, hides it, and
/// prints the panel-visible state after each step, so the cost of a hidden panel can be
/// measured without clicking the menu bar. The MenuBarExtra status button itself ignores
/// performClick and synthetic mouse events, so it cannot be driven from inside the app.
enum DebugHooks {
    static var startsInSettings: Bool { ProcessInfo.processInfo.arguments.contains("-MHShowSettings") }

    @MainActor
    static func runIfRequested(model: AppModel) {
        guard ProcessInfo.processInfo.arguments.contains("-MHWindowTest") else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 360, height: 640),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MarketPanelView(model: model))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(5))
            say("shown: panel visible \(model.isPanelVisible)")
            window.orderOut(nil)
            try? await Task.sleep(for: .seconds(2))
            say("hidden: panel visible \(model.isPanelVisible)")
        }
    }

    private static func say(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
#endif
