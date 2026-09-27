import SwiftUI

@main
struct MarketHoursApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MarketPanelView(model: model)
        } label: {
            Image(nsImage: model.menuBarImage)
                .accessibilityLabel(model.menuBarAccessibilityText)
        }
        .menuBarExtraStyle(.window)
    }
}
