import Foundation

/// A local notification to schedule ahead of an open or close.
public struct PlannedAlert: Equatable, Sendable {
    public let marketID: String
    public let event: MarketEvent
    public let fireDate: Date
    public let title: String
    public let body: String

    public var identifier: String {
        "markethours.\(marketID).\(event.kind == .open ? "open" : "close").\(Int(event.date.timeIntervalSince1970))"
    }
}

public enum AlertPlanner {
    /// Alerts `lead` seconds before every open and close within `horizon` of `now`,
    /// soonest first, at most `limit` (macOS keeps 64 pending per app). Lunch breaks
    /// are skipped. Times in the body are in the viewer's zone.
    public static func plan(
        schedules: [MarketSchedule], from now: Date, lead: TimeInterval,
        horizon: TimeInterval, limit: Int, viewer: TimeZone
    ) -> [PlannedAlert] {
        let leadMinutes = Int((lead / 60).rounded())
        var alerts: [(order: Int, alert: PlannedAlert)] = []
        for (order, schedule) in schedules.enumerated() {
            let market = schedule.market
            for event in schedule.events(from: now, to: now.addingTimeInterval(horizon)) {
                guard event.kind == .open || event.kind == .close else { continue }
                let fireDate = event.date.addingTimeInterval(-lead)
                guard fireDate > now else { continue }
                let opens = event.kind == .open
                alerts.append((order, PlannedAlert(
                    marketID: market.id, event: event, fireDate: fireDate,
                    title: "\(market.name) \(opens ? "opens" : "closes") in \(leadMinutes) min",
                    body: "\(opens ? "Opens" : "Closes") at \(clockText(event.date, in: viewer)) your time.")))
            }
        }
        alerts.sort { ($0.alert.fireDate, $0.order) < ($1.alert.fireDate, $1.order) }
        return alerts.prefix(limit).map(\.alert)
    }
}
