import Foundation

public enum Phase: Equatable, Sendable {
    case open
    case lunch
    case closed
}

public enum ClosedReason: Equatable, Sendable {
    case weekend
    case holiday(String)
    case outsideHours
}

public struct MarketEvent: Equatable, Sendable, CustomStringConvertible {
    public enum Kind: Equatable, Sendable {
        case open
        case close
        case lunchStart
        case lunchEnd
    }

    public let kind: Kind
    public let date: Date

    public init(kind: Kind, date: Date) {
        self.kind = kind
        self.date = date
    }

    /// True when trading starts or resumes at this event.
    public var startsTrading: Bool { kind == .open || kind == .lunchEnd }

    public var description: String { "\(kind) at \(date)" }
}

public struct MarketStatus: Equatable, Sendable {
    public let phase: Phase
    /// The next change of phase.
    public let next: MarketEvent
    /// Why the market is closed; nil while open or at lunch.
    public let closedReason: ClosedReason?
    /// The session in progress, open to close; nil while closed.
    public let session: DateInterval?
    /// Today's session runs on non-regular hours, such as an early close.
    public let isSpecialSession: Bool

    public func countdown(at date: Date) -> TimeInterval {
        next.date.timeIntervalSince(date)
    }

    /// Share of the session elapsed, open to close, while the market is open or at lunch.
    public func progress(at date: Date) -> Double? {
        guard let session, session.duration > 0 else { return nil }
        return min(max(date.timeIntervalSince(session.start) / session.duration, 0), 1)
    }

    /// Open, and the final close of the day is at most `threshold` away.
    public func isClosingSoon(at date: Date, within threshold: TimeInterval = 15 * 60) -> Bool {
        phase == .open && next.kind == .close && countdown(at: date) <= threshold
    }
}

/// Holidays and non-regular sessions for one market, keyed by exchange-local "YYYY-MM-DD".
struct MarketOverrides: Sendable {
    let coverageFirst: String
    let coverageLast: String
    let holidays: [String: String]
    let special: [String: SpecialSession]
}

/// A session whose hours differ from the regular ones. Missing fields keep the regular value.
struct SpecialSession: Sendable {
    var open: LocalTime?
    var close: LocalTime?
    var breaks: [TradingBreak]?

    func applied(to regular: SessionHours) -> SessionHours {
        let open = self.open ?? regular.open
        let close = self.close ?? regular.close
        // A regular break that no longer fits, like the lunch break on a half day, is dropped.
        let breaks = self.breaks ?? regular.breaks.filter { open <= $0.start && $0.end <= close }
        return SessionHours(open: open, close: close, breaks: breaks)
    }
}

/// Answers "is it open, and what happens next" for one market. Pure and thread-safe.
public struct MarketSchedule: Sendable {
    public let market: Market
    let overrides: MarketOverrides?
    let calendar: Calendar

    public init(market: Market) {
        self.init(market: market, overrides: nil)
    }

    init(market: Market, overrides: MarketOverrides?) {
        self.market = market
        self.overrides = overrides
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = market.timeZone
        self.calendar = calendar
    }

    public func status(at date: Date) -> MarketStatus {
        let today = localDay(containing: date)
        let reason: ClosedReason
        switch tradingDay(today) {
        case .closed(let why):
            reason = why
        case .session(let hours, let special):
            if let session = resolve(hours, on: today) {
                if date < session.open {
                    return MarketStatus(
                        phase: .closed, next: MarketEvent(kind: .open, date: session.open),
                        closedReason: .outsideHours, session: nil, isSpecialSession: special)
                }
                if date < session.close {
                    return inSession(session, at: date, special: special)
                }
            }
            reason = .outsideHours
        }
        let open = nextSession(after: today)?.open ?? .distantFuture
        return MarketStatus(
            phase: .closed, next: MarketEvent(kind: .open, date: open),
            closedReason: reason, session: nil, isSpecialSession: false)
    }

    /// Every open, close and break boundary in (start, end], in order.
    public func events(from start: Date, to end: Date) -> [MarketEvent] {
        var events: [MarketEvent] = []
        var day = localDay(containing: start)
        while let noon = day.noon, noon <= end.addingTimeInterval(86_400) {
            if case .session(let hours, _) = tradingDay(day), let session = resolve(hours, on: day) {
                events.append(MarketEvent(kind: .open, date: session.open))
                for pause in session.breaks {
                    events.append(MarketEvent(kind: .lunchStart, date: pause.start))
                    events.append(MarketEvent(kind: .lunchEnd, date: pause.end))
                }
                events.append(MarketEvent(kind: .close, date: session.close))
            }
            guard let next = day.adding(days: 1) else { break }
            day = next
        }
        return events.filter { $0.date > start && $0.date <= end }
    }

    /// The session in progress, or else the one the next open starts.
    public func displayedSession(at date: Date) -> DateInterval? {
        let status = status(at: date)
        if let session = status.session { return session }
        guard status.next.kind == .open else { return nil }
        let day = localDay(containing: status.next.date)
        guard case .session(let hours, _) = tradingDay(day), let session = resolve(hours, on: day) else {
            return nil
        }
        return DateInterval(start: session.open, end: session.close)
    }

    /// "16:30-23:00": the displayed session in the viewer's time zone.
    public func sessionRangeText(at date: Date, in viewer: TimeZone) -> String {
        guard let session = displayedSession(at: date) else { return "" }
        return clockText(session.start, in: viewer) + "-" + clockText(session.end, in: viewer)
    }

    /// "09:45:12": the exchange's own wall clock, seconds truncated.
    public func localClockText(at date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return [parts.hour, parts.minute, parts.second].map { twoDigits($0 ?? 0) }.joined(separator: ":")
    }

    // MARK: - Internals

    enum TradingDay {
        case session(SessionHours, special: Bool)
        case closed(ClosedReason)
    }

    struct ResolvedSession {
        let open: Date
        let close: Date
        let breaks: [DateInterval]
    }

    struct LocalDay {
        let calendar: Calendar
        let year: Int
        let month: Int
        let day: Int
        let weekday: Int

        var key: String { "\(year)-\(twoDigits(month))-\(twoDigits(day))" }

        func date(at time: LocalTime) -> Date? {
            calendar.date(from: DateComponents(
                year: year, month: month, day: day, hour: time.hour, minute: time.minute))
        }

        var noon: Date? { date(at: LocalTime(12, 0)) }

        func adding(days: Int) -> LocalDay? {
            guard let noon, let moved = calendar.date(byAdding: .day, value: days, to: noon) else { return nil }
            return LocalDay(calendar: calendar, date: moved)
        }
    }

    func localDay(containing date: Date) -> LocalDay {
        LocalDay(calendar: calendar, date: date)
    }

    func tradingDay(_ day: LocalDay) -> TradingDay {
        // Gregorian weekday: 1 is Sunday, 7 is Saturday.
        if day.weekday == 1 || day.weekday == 7 { return .closed(.weekend) }
        guard let overrides else { return .session(market.regular, special: false) }
        let key = day.key
        guard key >= overrides.coverageFirst, key <= overrides.coverageLast else {
            return .session(market.regular, special: false)
        }
        if let name = overrides.holidays[key] { return .closed(.holiday(name)) }
        if let special = overrides.special[key] {
            return .session(special.applied(to: market.regular), special: true)
        }
        return .session(market.regular, special: false)
    }

    func resolve(_ hours: SessionHours, on day: LocalDay) -> ResolvedSession? {
        guard let open = day.date(at: hours.open), let close = day.date(at: hours.close), open < close else {
            return nil
        }
        let breaks = hours.breaks
            .sorted { $0.start < $1.start }
            .compactMap { pause -> DateInterval? in
                guard let start = day.date(at: pause.start), let end = day.date(at: pause.end),
                      open <= start, start < end, end <= close else { return nil }
                return DateInterval(start: start, end: end)
            }
        return ResolvedSession(open: open, close: close, breaks: breaks)
    }

    func inSession(_ session: ResolvedSession, at date: Date, special: Bool) -> MarketStatus {
        let span = DateInterval(start: session.open, end: session.close)
        if let pause = session.breaks.first(where: { $0.start <= date && date < $0.end }) {
            return MarketStatus(
                phase: .lunch, next: MarketEvent(kind: .lunchEnd, date: pause.end),
                closedReason: nil, session: span, isSpecialSession: special)
        }
        let next = session.breaks.first(where: { $0.start > date })
            .map { MarketEvent(kind: .lunchStart, date: $0.start) }
            ?? MarketEvent(kind: .close, date: session.close)
        return MarketStatus(phase: .open, next: next, closedReason: nil, session: span, isSpecialSession: special)
    }

    /// The first trading session on a day after `day`. Holidays never run for weeks,
    /// so a month of lookahead is plenty.
    func nextSession(after day: LocalDay) -> ResolvedSession? {
        var candidate = day
        for _ in 0..<31 {
            guard let next = candidate.adding(days: 1) else { return nil }
            candidate = next
            if case .session(let hours, _) = tradingDay(candidate), let session = resolve(hours, on: candidate) {
                return session
            }
        }
        return nil
    }
}

extension MarketSchedule.LocalDay {
    init(calendar: Calendar, date: Date) {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        self.init(
            calendar: calendar, year: parts.year ?? 1970, month: parts.month ?? 1,
            day: parts.day ?? 1, weekday: parts.weekday ?? 1)
    }
}

/// "HH:mm" for `date` in `zone`, independent of the user's locale.
func clockText(_ date: Date, in zone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return twoDigits(parts.hour ?? 0) + ":" + twoDigits(parts.minute ?? 0)
}
