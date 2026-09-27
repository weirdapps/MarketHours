import Foundation

/// A wall-clock time of day in an exchange's own time zone.
public struct LocalTime: Hashable, Comparable, Sendable, CustomStringConvertible {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Parses "HH:mm".
    public init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.init(hour, minute)
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public var description: String { twoDigits(hour) + ":" + twoDigits(minute) }
}

/// A trading halt inside a session, such as a lunch break: [start, end).
public struct TradingBreak: Hashable, Sendable {
    public var start: LocalTime
    public var end: LocalTime

    public init(_ start: LocalTime, _ end: LocalTime) {
        self.start = start
        self.end = end
    }
}

/// One day's trading hours in exchange-local time: [open, close) minus the breaks.
public struct SessionHours: Hashable, Sendable, CustomStringConvertible {
    public var open: LocalTime
    public var close: LocalTime
    public var breaks: [TradingBreak]

    public init(open: LocalTime, close: LocalTime, breaks: [TradingBreak] = []) {
        self.open = open
        self.close = close
        self.breaks = breaks
    }

    public var description: String {
        "\(open)-\(close)" + breaks.map { " break \($0.start)-\($0.end)" }.joined()
    }
}

public struct Market: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let exchange: String
    public let shortName: String
    public let flag: String
    public let timeZoneIdentifier: String
    /// Hours on a normal trading day. Holidays and early closes come from `SessionData`.
    public let regular: SessionHours

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
    }

    public static let all: [Market] = [
        Market(
            id: "ny", name: "New York", exchange: "NYSE / Nasdaq", shortName: "NY", flag: "🇺🇸",
            timeZoneIdentifier: "America/New_York",
            regular: SessionHours(open: LocalTime(9, 30), close: LocalTime(16, 0))
        ),
        Market(
            id: "london", name: "London", exchange: "LSE", shortName: "LON", flag: "🇬🇧",
            timeZoneIdentifier: "Europe/London",
            regular: SessionHours(open: LocalTime(8, 0), close: LocalTime(16, 30))
        ),
        Market(
            id: "frankfurt", name: "Frankfurt", exchange: "Xetra", shortName: "FRA", flag: "🇩🇪",
            timeZoneIdentifier: "Europe/Berlin",
            regular: SessionHours(open: LocalTime(9, 0), close: LocalTime(17, 30))
        ),
        // Euronext Athens Cash Markets Schedule (March 2026): call auction 10:15-10:30,
        // continuous trading from 10:30, closing auction 17:00-17:10, trading at the
        // close until 17:20. exchange_calendars opens ASEX at 10:00; the app does not.
        Market(
            id: "athens", name: "Athens", exchange: "Euronext Athens", shortName: "ATH", flag: "🇬🇷",
            timeZoneIdentifier: "Europe/Athens",
            regular: SessionHours(open: LocalTime(10, 30), close: LocalTime(17, 20))
        ),
        // The TSE afternoon session runs to 15:30 since 5 Nov 2024.
        Market(
            id: "tokyo", name: "Tokyo", exchange: "TSE", shortName: "TYO", flag: "🇯🇵",
            timeZoneIdentifier: "Asia/Tokyo",
            regular: SessionHours(
                open: LocalTime(9, 0), close: LocalTime(15, 30),
                breaks: [TradingBreak(LocalTime(11, 30), LocalTime(12, 30))]
            )
        ),
        Market(
            id: "hongkong", name: "Hong Kong", exchange: "HKEX", shortName: "HK", flag: "🇭🇰",
            timeZoneIdentifier: "Asia/Hong_Kong",
            regular: SessionHours(
                open: LocalTime(9, 30), close: LocalTime(16, 0),
                breaks: [TradingBreak(LocalTime(12, 0), LocalTime(13, 0))]
            )
        ),
        Market(
            id: "sydney", name: "Sydney", exchange: "ASX", shortName: "SYD", flag: "🇦🇺",
            timeZoneIdentifier: "Australia/Sydney",
            regular: SessionHours(open: LocalTime(10, 0), close: LocalTime(16, 0))
        ),
    ]
}

func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
}
