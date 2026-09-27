import Foundation
import Testing
@testable import MarketHoursCore

// Expected instants are worked out by hand from each exchange's published hours
// and its zone's UTC offset on that date.

@Suite struct RegularHoursTests {
    @Test func tokyoLunchBreakIsNotOpen() {
        let status = schedule("tokyo").status(at: utc("2026-09-28T03:00:00Z")) // Mon 12:00 JST
        #expect(status.phase == .lunch)
        #expect(status.next == MarketEvent(kind: .lunchEnd, date: utc("2026-09-28T03:30:00Z")))
    }

    @Test func tokyoTradesUntil1530() {
        let status = schedule("tokyo").status(at: utc("2026-09-28T06:15:00Z")) // 15:15 JST
        #expect(status.phase == .open)
        #expect(status.next == MarketEvent(kind: .close, date: utc("2026-09-28T06:30:00Z")))
    }

    @Test func tokyoMorningCountsDownToLunch() {
        let status = schedule("tokyo").status(at: utc("2026-09-28T01:00:00Z")) // 10:00 JST
        #expect(status.phase == .open)
        #expect(status.next == MarketEvent(kind: .lunchStart, date: utc("2026-09-28T02:30:00Z")))
    }

    @Test func hongKongLunchBreakIsNotOpen() {
        let status = schedule("hongkong").status(at: utc("2026-09-28T04:30:00Z")) // 12:30 HKT
        #expect(status.phase == .lunch)
        #expect(status.next == MarketEvent(kind: .lunchEnd, date: utc("2026-09-28T05:00:00Z")))
    }

    @Test func breakStartMinuteIsLunchAndBreakEndMinuteIsOpen() {
        let hongKong = schedule("hongkong")
        #expect(hongKong.status(at: utc("2026-09-28T04:00:00Z")).phase == .lunch)
        #expect(hongKong.status(at: utc("2026-09-28T05:00:00Z")).phase == .open)
    }

    @Test func openMinuteIsOpenAndCloseMinuteIsClosed() {
        let newYork = schedule("ny")
        #expect(newYork.status(at: utc("2026-09-28T13:30:00Z")).phase == .open)
        let atClose = newYork.status(at: utc("2026-09-28T20:00:00Z"))
        #expect(atClose.phase == .closed)
        #expect(atClose.closedReason == .outsideHours)
        #expect(atClose.next == MarketEvent(kind: .open, date: utc("2026-09-29T13:30:00Z")))
    }

    @Test func athensTradesFrom1030To1720() {
        let athens = schedule("athens")
        let callAuction = athens.status(at: utc("2026-09-28T07:15:00Z")) // 10:15 EEST
        #expect(callAuction.phase == .closed)
        #expect(callAuction.next == MarketEvent(kind: .open, date: utc("2026-09-28T07:30:00Z")))
        let tradingAtLast = athens.status(at: utc("2026-09-28T14:10:00Z")) // 17:10 EEST
        #expect(tradingAtLast.phase == .open)
        #expect(tradingAtLast.next == MarketEvent(kind: .close, date: utc("2026-09-28T14:20:00Z")))
    }

    @Test func weekendIsClosedUntilMondayOpen() {
        let status = schedule("london").status(at: utc("2026-10-03T12:00:00Z")) // Saturday
        #expect(status.phase == .closed)
        #expect(status.closedReason == .weekend)
        #expect(status.next == MarketEvent(kind: .open, date: utc("2026-10-05T07:00:00Z")))
    }

    @Test func progressRunsFromOpenToClose() {
        let newYork = schedule("ny")
        let now = utc("2026-09-28T16:45:00Z") // 12:45 EDT, half of 09:30-16:00
        #expect(newYork.status(at: now).progress(at: now) == 0.5)
        let closed = utc("2026-09-28T21:00:00Z")
        #expect(newYork.status(at: closed).progress(at: closed) == nil)
    }

    @Test func closingSoonOnlyInTheLastFifteenMinutesBeforeTheClose() {
        let london = schedule("london")
        let sixteenMinutes = utc("2026-09-28T15:14:00Z")
        let fifteenMinutes = utc("2026-09-28T15:15:00Z")
        #expect(!london.status(at: sixteenMinutes).isClosingSoon(at: sixteenMinutes))
        #expect(london.status(at: fifteenMinutes).isClosingSoon(at: fifteenMinutes))
        let beforeLunch = utc("2026-09-28T02:20:00Z") // Tokyo, 10 min before lunch
        #expect(!schedule("tokyo").status(at: beforeLunch).isClosingSoon(at: beforeLunch))
    }
}

@Suite struct DaylightSavingTests {
    @Test(arguments: [
        ("sydney", "2026-10-02T06:30:00Z", "2026-10-04T23:00:00Z"), // AEST to AEDT, Sun 4 Oct
        ("london", "2026-10-23T15:30:00Z", "2026-10-26T08:00:00Z"), // BST to GMT, Sun 25 Oct
        ("ny", "2026-10-30T20:00:00Z", "2026-11-02T14:30:00Z"),     // EDT to EST, Sun 1 Nov
    ])
    func nextOpenAcrossTransition(id: String, at instant: String, expectedOpen: String) {
        let status = schedule(id).status(at: utc(instant))
        #expect(status.phase == .closed)
        #expect(status.next == MarketEvent(kind: .open, date: utc(expectedOpen)))
    }

    @Test func newYorkOpensAt1330UTCWhileEuropeIsOnWinterTime() {
        // 9 Mar 2026: New York is on EDT, Frankfurt stays on CET until 29 Mar.
        #expect(schedule("ny").status(at: utc("2026-03-09T13:29:00Z")).phase == .closed)
        #expect(schedule("ny").status(at: utc("2026-03-09T13:30:00Z")).phase == .open)
        #expect(schedule("frankfurt").status(at: utc("2026-03-09T08:00:00Z")).phase == .open)
    }
}

@Suite struct SessionRangeTests {
    @Test func showsTodaysSessionInTheViewersTime() {
        let morning = utc("2026-09-28T10:00:00Z")
        #expect(schedule("ny").sessionRangeText(at: morning, in: athensTime) == "16:30-23:00")
    }

    @Test func showsTheNextSessionOnceTodaysHasEnded() {
        let afterTokyoClose = utc("2026-09-28T10:00:00Z")
        #expect(schedule("tokyo").sessionRangeText(at: afterTokyoClose, in: athensTime) == "03:00-09:30")
    }
}

@Suite struct LocalClockTests {
    @Test func showsEachExchangesWallClock() {
        let instant = utc("2026-09-28T13:45:12Z")
        #expect(schedule("ny").localClockText(at: instant) == "09:45:12")
        #expect(schedule("athens").localClockText(at: instant) == "16:45:12")
        #expect(schedule("tokyo").localClockText(at: instant) == "22:45:12")
    }

    @Test func dropsFractionsOfASecond() {
        let instant = utc("2026-09-28T13:29:59Z").addingTimeInterval(0.9)
        #expect(schedule("ny").localClockText(at: instant) == "09:29:59")
    }
}
