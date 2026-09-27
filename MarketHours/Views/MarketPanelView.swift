import AppKit
import MarketHoursCore
import SwiftUI

struct MarketPanelView: View {
    let model: AppModel
    #if DEBUG
    @State private var showingSettings = DebugHooks.startsInSettings
    #else
    @State private var showingSettings = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            CappedScrollView(maxHeight: Self.maxContentHeight) {
                if showingSettings {
                    SettingsView(model: model, settings: model.settings)
                } else {
                    MarketListView(model: model)
                }
            }
            Divider().opacity(0.35)
            footer
        }
        .frame(width: 360)
        .background(WindowVisibilityReader { model.setPanelVisible($0, window: $1) })
        .onAppear { model.setPanelVisible(true, window: nil) }
        .onDisappear { model.setPanelVisible(false, window: nil) }
    }

    /// Screen height less room for the header, footer and menu bar.
    private static var maxContentHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 150
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.85), Color.cyan.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Market Hours")
                    .font(.headline)
                Text(showingSettings ? "Settings" : "Sessions in \(model.viewerCity) time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "checkmark.circle.fill" : "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help(showingSettings ? "Done" : "Settings (⌘,)")
            .accessibilityLabel(showingSettings ? "Done" : "Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text(model.holidayDataSummary)
                .font(.caption2)
                .foregroundStyle(model.holidayDataEndsSoon ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Visible markets, soonest event first.
struct MarketListView: View {
    let model: AppModel

    var body: some View {
        let now = model.panelNow
        let viewer = TimeZone.autoupdatingCurrent
        let rows = model.visibleSchedules.enumerated()
            .map { (order: $0.offset, schedule: $0.element, status: $0.element.status(at: now)) }
            .sorted { ($0.status.next.date, $0.order) < ($1.status.next.date, $1.order) }
        VStack(spacing: 6) {
            if rows.isEmpty {
                Text("No markets selected. Choose some in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }
            ForEach(rows, id: \.schedule.market.id) { row in
                MarketRowView(schedule: row.schedule, status: row.status, now: now, viewer: viewer)
            }
        }
        .padding(12)
    }
}

/// Takes its content's height up to `maxHeight`, then scrolls. MenuBarExtra sizes its
/// window to the content, so the panel stays compact on a tall screen and cannot run
/// off a short one.
struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ContentHeightKey.self, value: geometry.size.height)
                })
        }
        .frame(height: min(max(contentHeight, 1), maxHeight))
        .onPreferenceChange(ContentHeightKey.self) { height in
            Task { @MainActor in contentHeight = height }
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
