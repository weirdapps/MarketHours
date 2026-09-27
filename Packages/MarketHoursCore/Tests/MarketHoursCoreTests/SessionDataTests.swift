import Foundation
import Testing
@testable import MarketHoursCore

@Suite struct SessionDataTests {
    @Test func holidayIsClosedAndCarriesItsName() throws {
        let status = try sampleSessionData().schedule(for: market("ny")).status(at: utc("2026-11-26T15:00:00Z"))
        #expect(status.phase == .closed)
        #expect(status.closedReason == .holiday("Thanksgiving"))
        #expect(status.next == MarketEvent(kind: .open, date: utc("2026-11-27T14:30:00Z")))
    }

    @Test func earlyCloseEndsTheSessionAt1300() throws {
        let newYork = try sampleSessionData().schedule(for: market("ny"))
        let midday = newYork.status(at: utc("2026-11-27T17:30:00Z")) // 12:30 EST
        #expect(midday.phase == .open)
        #expect(midday.isSpecialSession)
        #expect(midday.next == MarketEvent(kind: .close, date: utc("2026-11-27T18:00:00Z")))
        let after = newYork.status(at: utc("2026-11-27T18:30:00Z"))
        #expect(after.phase == .closed)
        #expect(after.next == MarketEvent(kind: .open, date: utc("2026-11-30T14:30:00Z")))
    }

    @Test func halfDayDropsTheLunchBreak() throws {
        let hongKong = try sampleSessionData().schedule(for: market("hongkong"))
        let status = hongKong.status(at: utc("2026-12-24T03:30:00Z")) // 11:30 HKT
        #expect(status.phase == .open)
        #expect(status.next == MarketEvent(kind: .close, date: utc("2026-12-24T04:00:00Z")))
    }

    @Test func marketMissingFromTheDataKeepsTheWeekdayRule() throws {
        // London has no entry in the sample, so Friday 25 Dec 2026 counts as a trading day.
        let london = try sampleSessionData().schedule(for: market("london"))
        #expect(london.status(at: utc("2026-12-25T10:00:00Z")).phase == .open)
    }

    @Test func coverageEndsOnItsLastDay() throws {
        let data = try sampleSessionData()
        #expect(data.coverageLast == "2026-12-31")
        #expect(data.covers(utc("2026-12-31T12:00:00Z")))
        #expect(!data.covers(utc("2027-01-02T12:00:00Z")))
    }

    @Test func rejectsAnUnknownSchemaVersion() {
        let future = sampleSessionJSON.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
        #expect(throws: (any Error).self) { try SessionData(jsonData: Data(future.utf8)) }
    }
}
