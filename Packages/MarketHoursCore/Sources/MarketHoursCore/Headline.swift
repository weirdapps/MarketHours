import Foundation

/// The one countdown the menu bar shows.
public struct Headline: Equatable, Sendable {
    public let market: Market
    public let event: MarketEvent

    /// The pinned market's next event, even if that market is hidden; otherwise the soonest
    /// event of any kind among the markets not hidden, or nil when every one is hidden.
    /// Simultaneous events go to the market listed first.
    public static func pick(
        from schedules: [MarketSchedule], at date: Date, pinned: String?, hidden: Set<String> = []
    ) -> Headline? {
        if let pinned, let schedule = schedules.first(where: { $0.market.id == pinned }) {
            return Headline(market: schedule.market, event: schedule.status(at: date).next)
        }
        var best: Headline?
        for schedule in schedules where !hidden.contains(schedule.market.id) {
            let event = schedule.status(at: date).next
            if best.map({ event.date < $0.event.date }) ?? true {
                best = Headline(market: schedule.market, event: event)
            }
        }
        return best
    }

    /// "▲🇺🇸 5m": ▲ when trading starts or resumes, ▼ when it stops, then the market's flag.
    public func menuBarText(at date: Date, showSeconds: Bool) -> String {
        let arrow = event.startsTrading ? "▲" : "▼"
        let countdown = DurationFormat.compact(event.date.timeIntervalSince(date), showSeconds: showSeconds)
        return "\(arrow)\(market.flag) \(countdown)"
    }

    /// "London closes in 2 hours 5 minutes".
    public func accessibilityText(at date: Date) -> String {
        let verb: String
        switch event.kind {
        case .open: verb = "opens"
        case .close: verb = "closes"
        case .lunchStart: verb = "breaks for lunch"
        case .lunchEnd: verb = "resumes"
        }
        return "\(market.name) \(verb) in \(DurationFormat.spoken(event.date.timeIntervalSince(date)))"
    }
}
