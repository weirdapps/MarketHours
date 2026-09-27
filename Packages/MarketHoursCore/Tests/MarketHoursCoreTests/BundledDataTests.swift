import Foundation
import Testing
@testable import MarketHoursCore

/// Checks against the generated sessions.json and the exchange_calendars oracle
/// sample (scripts/generate_sessions.py writes both).
@Suite struct BundledDataTests {
    @Test func bundledDataLoadsAndCoversTheNextTwoYears() throws {
        let data = try #require(SessionData.bundled)
        #expect(data.covers(utc("2026-10-01T12:00:00Z")))
        #expect(data.covers(utc("2028-06-30T12:00:00Z")))
    }

    @Test func appHoursMatchTheCalendarExceptTheAthensOpen() throws {
        let data = try #require(SessionData.bundled)
        for market in Market.all {
            let calendar = try #require(data.calendarRegular(for: market.id), "no data for \(market.id)")
            var expected = market.regular
            if market.id == "athens" { expected.open = LocalTime(10, 0) }
            #expect(calendar == expected, "\(market.id): calendar \(calendar) vs app \(market.regular)")
        }
    }

    @Test func matchesTheExchangeCalendarsOracle() throws {
        let data = try #require(SessionData.bundled)
        let url = try #require(Bundle.module.url(forResource: "oracle_sample", withExtension: "csv", subdirectory: "Fixtures"))
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst()
        #expect(lines.count > 1_000)
        let phases: [String: Phase] = ["open": .open, "break": .lunch, "closed": .closed]
        let kinds: [String: MarketEvent.Kind] = [
            "open": .open, "close": .close, "break_start": .lunchStart, "break_end": .lunchEnd,
        ]
        var schedules: [String: MarketSchedule] = [:]
        for market in Market.all { schedules[market.id] = data.schedule(for: market) }
        var mismatches: [String] = []
        for line in lines {
            let f = line.split(separator: ",").map(String.init)
            let at = Date(timeIntervalSince1970: TimeInterval(f[0])!)
            let status = try #require(schedules[f[1]]).status(at: at)
            let expected = MarketEvent(kind: kinds[f[4]]!, date: Date(timeIntervalSince1970: TimeInterval(f[3])!))
            if status.phase != phases[f[2]] || status.next != expected {
                mismatches.append("\(line) -> \(status.phase) \(status.next)")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5))")
    }
}
