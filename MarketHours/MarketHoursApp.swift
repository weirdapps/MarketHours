import SwiftUI

@main
struct MarketHoursApp: App {
    @StateObject private var clock = MarketClock()

    var body: some Scene {
        MenuBarExtra {
            MarketPanelView()
                .environmentObject(clock)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                if !clock.menuBarSubtitle.isEmpty {
                    Text(clock.menuBarSubtitle)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
