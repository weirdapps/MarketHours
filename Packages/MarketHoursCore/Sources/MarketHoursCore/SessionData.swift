import Foundation

public enum SessionDataError: Error, Equatable {
    case unsupportedSchema(Int)
    case badTime(String)
}

/// Exchange holidays and non-regular sessions, generated from exchange_calendars by
/// scripts/generate_sessions.py and bundled as sessions.json.
public struct SessionData: Sendable {
    /// First and last exchange-local day the data describes, "YYYY-MM-DD".
    public let coverageFirst: String
    public let coverageLast: String
    /// Where the data came from, e.g. "exchange_calendars 4.13.2".
    public let source: String
    let markets: [String: MarketData]

    struct MarketData: Sendable {
        let calendarRegular: SessionHours
        let holidays: [String: String]
        let special: [String: SpecialSession]
    }

    public init(jsonData: Data) throws {
        let file = try JSONDecoder().decode(FileFormat.self, from: jsonData)
        guard file.schemaVersion == 1 else { throw SessionDataError.unsupportedSchema(file.schemaVersion) }
        coverageFirst = file.coverage.first
        coverageLast = file.coverage.last
        source = file.source
        markets = try file.markets.mapValues { market in
            MarketData(
                calendarRegular: SessionHours(
                    open: try parseTime(market.calendarRegular.open),
                    close: try parseTime(market.calendarRegular.close),
                    breaks: try parseBreaks(market.calendarRegular.breaks)),
                holidays: market.holidays,
                special: try market.special.mapValues { special in
                    SpecialSession(
                        open: try special.open.map(parseTime),
                        close: try special.close.map(parseTime),
                        breaks: try special.breaks.map(parseBreaks))
                })
        }
    }

    /// The copy shipped inside the app, or nil if it is missing or unreadable, in which
    /// case every market falls back to its regular weekday hours.
    public static let bundled: SessionData? = {
        guard let url = Bundle.module.url(forResource: "sessions", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? SessionData(jsonData: data)
    }()

    public func schedule(for market: Market) -> MarketSchedule {
        guard let data = markets[market.id] else { return MarketSchedule(market: market) }
        return MarketSchedule(market: market, overrides: MarketOverrides(
            coverageFirst: coverageFirst, coverageLast: coverageLast,
            holidays: data.holidays, special: data.special))
    }

    /// Whether `date`'s UTC day falls inside the coverage window.
    public func covers(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = MarketSchedule.LocalDay(calendar: calendar, date: date).key
        return day >= coverageFirst && day <= coverageLast
    }

    /// The regular hours exchange_calendars reports, for checking the app's table.
    public func calendarRegular(for marketID: String) -> SessionHours? {
        markets[marketID]?.calendarRegular
    }
}

private struct FileFormat: Decodable {
    struct Coverage: Decodable {
        let first: String
        let last: String
    }

    struct Hours: Decodable {
        let open: String
        let close: String
        let breaks: [[String]]
    }

    struct Special: Decodable {
        let open: String?
        let close: String?
        let breaks: [[String]]?
    }

    struct MarketEntry: Decodable {
        let calendarRegular: Hours
        let holidays: [String: String]
        let special: [String: Special]
    }

    let schemaVersion: Int
    let source: String
    let coverage: Coverage
    let markets: [String: MarketEntry]
}

private func parseTime(_ text: String) throws -> LocalTime {
    guard let time = LocalTime(text) else { throw SessionDataError.badTime(text) }
    return time
}

private func parseBreaks(_ pairs: [[String]]) throws -> [TradingBreak] {
    try pairs.map { pair in
        guard pair.count == 2 else { throw SessionDataError.badTime(pair.joined(separator: "-")) }
        return TradingBreak(try parseTime(pair[0]), try parseTime(pair[1]))
    }
}
