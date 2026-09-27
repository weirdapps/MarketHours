import AppKit
import MarketHoursCore
import Observation
import UserNotifications

/// Keeps the pending notifications equal to the latest alert plan. Asks for permission
/// only when the plan is non-empty, which means the user turned alerts on.
@MainActor
@Observable
final class AlertScheduler: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @ObservationIgnored private var generation = 0

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        authorization = await Self.currentAuthorization()
    }

    func replacePending(with plan: [PlannedAlert]) {
        generation += 1
        let run = generation
        Task {
            let center = UNUserNotificationCenter.current()
            let ours = await Self.pendingIdentifiers().filter { $0.hasPrefix("markethours.") }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            guard !plan.isEmpty else { return }
            if authorization == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                await refreshAuthorization()
            }
            guard run == generation, authorization == .authorized || authorization == .provisional else { return }
            for alert in plan {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.body
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Self.components(alert.fireDate), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
            }
        }
    }

    func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The panel counts as the app being frontmost; show the banner anyway.
        [.banner, .list, .sound]
    }

    private nonisolated static func currentAuthorization() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private nonisolated static func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    /// Absolute trigger time: explicit calendar and zone, no weekday or nanosecond fields.
    private static func components(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        parts.calendar = calendar
        parts.timeZone = .current
        return parts
    }
}
