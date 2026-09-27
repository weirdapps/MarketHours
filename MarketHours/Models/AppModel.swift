import AppKit
import MarketHoursCore
import Observation
import os

/// App state. The menu bar label updates on the minute (on the second only if the user
/// asks for seconds). The panel clock ticks every second, but only while the panel is on
/// screen, so a closed panel costs nothing.
@MainActor
@Observable
final class AppModel {
    let settings = Settings()
    let launchAtLogin = LaunchAtLogin()
    let alerts = AlertScheduler()
    let sessionData: SessionData?
    /// Every market in display order, with holidays and early closes applied.
    let schedules: [MarketSchedule]

    private(set) var menuBarImage = NSImage()
    private(set) var menuBarAccessibilityText = "Market Hours"
    private(set) var panelNow = Date()
    private(set) var isPanelVisible = false

    @ObservationIgnored private var menuBarText = ""
    @ObservationIgnored private var menuTicker: AlignedTicker?
    @ObservationIgnored private var panelTicker: AlignedTicker?
    @ObservationIgnored private var alertsPlannedAt = Date.distantPast
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private weak var panelWindow: NSWindow?
    @ObservationIgnored private let log = Logger(subsystem: "com.weirdapps.MarketHours", category: "model")

    init() {
        let data = SessionData.bundled
        sessionData = data
        schedules = Market.all.map { data?.schedule(for: $0) ?? MarketSchedule(market: $0) }
        settings.onChange = { [weak self] in self?.settingsChanged($0) }
        startMenuTicker()
        refreshMenuBar()
        rescheduleAlerts()
        observeSystemEvents()
        #if DEBUG
        DebugHooks.runIfRequested(model: self)
        #endif
    }

    var visibleSchedules: [MarketSchedule] {
        let hidden = settings.hiddenMarketIDs
        return schedules.filter { !hidden.contains($0.market.id) }
    }

    /// "Athens", from the Mac's time zone.
    var viewerCity: String {
        let identifier = TimeZone.autoupdatingCurrent.identifier
        return identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    var holidayDataEndsSoon: Bool {
        guard let sessionData else { return true }
        return !sessionData.covers(Date().addingTimeInterval(60 * 86_400))
    }

    var holidayDataSummary: String {
        guard let sessionData else { return "Weekdays only: holiday data is missing" }
        return "Holidays to \(Self.displayDate(sessionData.coverageLast))"
    }

    var holidayDataDescription: String {
        guard let sessionData else {
            return "No holiday data is bundled, so every weekday counts as a trading day."
        }
        let end = Self.displayDate(sessionData.coverageLast)
        let refresh = holidayDataEndsSoon ? " Regenerate it soon with scripts/generate_sessions.py." : ""
        return "Holidays, early closes and lunch breaks from \(sessionData.source), through \(end).\(refresh)"
    }

    // MARK: - Panel

    func setPanelVisible(_ visible: Bool, window: NSWindow?) {
        if let window { panelWindow = window }
        guard visible != isPanelVisible else { return }
        isPanelVisible = visible
        log.debug("panel visible: \(visible)")
        panelTicker?.stop()
        panelTicker = nil
        guard visible else { return }
        panelNow = Date()
        Task { await alerts.refreshAuthorization() }
        panelTicker = AlignedTicker(interval: 1, tolerance: 0.05) { [weak self] in
            self?.panelTick()
        }
    }

    private func panelTick() {
        // Belt and braces: if a hide notification was missed, stop within a second.
        if let panelWindow, !panelWindow.isOnScreen {
            setPanelVisible(false, window: nil)
            return
        }
        panelNow = Date()
    }

    // MARK: - Menu bar

    /// With every market hidden and none pinned, the label is the chart icon alone.
    func refreshMenuBar() {
        let now = Date()
        let headline = Headline.pick(
            from: schedules, at: now, pinned: settings.pinnedMarketID, hidden: settings.hiddenMarketIDs)
        let text = headline?.menuBarText(at: now, showSeconds: settings.menuBarShowsSeconds) ?? ""
        if text != menuBarText || menuBarImage.size == .zero {
            menuBarText = text
            menuBarImage = MenuBarLabelRenderer.image(for: text)
        }
        let spoken = headline?.accessibilityText(at: now) ?? "Market Hours"
        if spoken != menuBarAccessibilityText {
            menuBarAccessibilityText = spoken
        }
    }

    private func startMenuTicker() {
        menuTicker?.stop()
        let seconds = settings.menuBarShowsSeconds
        menuTicker = AlignedTicker(interval: seconds ? 1 : 60, tolerance: seconds ? 0.05 : 0.5) { [weak self] in
            self?.menuTick()
        }
    }

    private func menuTick() {
        refreshMenuBar()
        // Roll the three-day alert horizon forward once an hour.
        if !settings.alertMarketIDs.isEmpty, Date().timeIntervalSince(alertsPlannedAt) >= 3_600 {
            rescheduleAlerts()
        }
    }

    // MARK: - Alerts

    func rescheduleAlerts() {
        alertsPlannedAt = Date()
        let chosen = settings.alertMarketIDs
        let plan = AlertPlanner.plan(
            schedules: schedules.filter { chosen.contains($0.market.id) },
            from: Date(), lead: TimeInterval(settings.alertLeadMinutes * 60),
            horizon: 3 * 86_400, limit: 60, viewer: .autoupdatingCurrent)
        alerts.replacePending(with: plan)
    }

    // MARK: - Changes

    private func settingsChanged(_ change: Settings.Change) {
        switch change {
        case .seconds:
            startMenuTicker()
            refreshMenuBar()
        case .shownMarkets, .pinnedMarket:
            refreshMenuBar()
        case .alerts:
            rescheduleAlerts()
        }
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.timeChanged() }
        })
        for name: Notification.Name in [.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.timeChanged() }
            })
        }
    }

    /// Wake, a clock change or a new time zone: re-align the tickers and re-plan alerts.
    private func timeChanged() {
        NSTimeZone.resetSystemTimeZone()
        startMenuTicker()
        if isPanelVisible {
            isPanelVisible = false
            setPanelVisible(true, window: nil)
        }
        refreshMenuBar()
        rescheduleAlerts()
    }

    /// "2028-12-31" to "31 Dec 2028".
    static func displayDate(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard parts.count == 3, (1...12).contains(parts[1]) else { return key }
        return "\(parts[2]) \(months[parts[1] - 1]) \(parts[0])"
    }
}
