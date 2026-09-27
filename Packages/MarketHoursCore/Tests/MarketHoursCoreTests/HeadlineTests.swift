import Foundation
import Testing
@testable import MarketHoursCore

@Suite struct HeadlineTests {
    let schedules = Market.all.map { MarketSchedule(market: $0) }
    let lateAfternoon = utc("2026-09-28T13:25:00Z") // 16:25 Athens: Europe open, New York opens 13:30Z

    @Test func autoPicksTheSoonestEventOfEitherKind() {
        let headline = Headline.pick(from: schedules, at: lateAfternoon, pinned: nil)
        #expect(headline?.market.id == "ny")
        #expect(headline?.event == MarketEvent(kind: .open, date: utc("2026-09-28T13:30:00Z")))
    }

    @Test func pinnedMarketWinsOverASoonerEvent() {
        let headline = Headline.pick(from: schedules, at: lateAfternoon, pinned: "london")
        #expect(headline?.market.id == "london")
        #expect(headline?.event.kind == .close)
    }

    @Test func unknownPinnedMarketFallsBackToAuto() {
        #expect(Headline.pick(from: schedules, at: lateAfternoon, pinned: "nowhere")?.market.id == "ny")
    }

    @Test func simultaneousEventsGoToTheEarlierMarketInTheList() {
        // London and Frankfurt both close at 15:30Z.
        #expect(Headline.pick(from: schedules, at: utc("2026-09-28T15:10:00Z"), pinned: nil)?.market.id == "london")
    }

    @Test func menuBarTextShowsDirectionMarketAndCountdown() throws {
        let opening = try #require(Headline.pick(from: schedules, at: lateAfternoon, pinned: nil))
        #expect(opening.menuBarText(at: lateAfternoon, showSeconds: false) == "▲NY 5m")
        let closing = try #require(Headline.pick(from: schedules, at: lateAfternoon, pinned: "london"))
        #expect(closing.menuBarText(at: lateAfternoon, showSeconds: false) == "▼LON 2h05m")
        #expect(closing.accessibilityText(at: lateAfternoon) == "London closes in 2 hours 5 minutes")
    }
}
