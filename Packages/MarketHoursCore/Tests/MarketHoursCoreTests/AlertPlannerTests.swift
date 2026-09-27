import Foundation
import Testing
@testable import MarketHoursCore

@Suite struct AlertPlannerTests {
    let lead: TimeInterval = 15 * 60

    @Test func plansOpenAndCloseAlertsAheadOfTime() throws {
        let plan = AlertPlanner.plan(
            schedules: [schedule("ny")], from: utc("2026-09-28T13:00:00Z"),
            lead: lead, horizon: 2 * 86_400, limit: 64, viewer: athensTime)
        #expect(plan.prefix(3).map(\.fireDate) == [
            utc("2026-09-28T13:15:00Z"), utc("2026-09-28T19:45:00Z"), utc("2026-09-29T13:15:00Z"),
        ])
        let first = try #require(plan.first)
        #expect(first.title == "New York opens in 15 min")
        #expect(first.body == "Opens at 16:30 your time.")
        #expect(plan[1].title == "New York closes in 15 min")
    }

    @Test func skipsAlertsWhoseTimeHasPassed() {
        let plan = AlertPlanner.plan(
            schedules: [schedule("ny")], from: utc("2026-09-28T13:20:00Z"),
            lead: lead, horizon: 86_400, limit: 64, viewer: athensTime)
        #expect(plan.first?.fireDate == utc("2026-09-28T19:45:00Z"))
    }

    @Test func ignoresLunchBreaks() {
        let plan = AlertPlanner.plan(
            schedules: [schedule("tokyo")], from: utc("2026-09-27T22:00:00Z"),
            lead: lead, horizon: 12 * 3_600, limit: 64, viewer: athensTime)
        #expect(plan.map(\.event.kind) == [.open, .close])
    }

    @Test func followsHolidaysAndEarlyCloses() throws {
        let newYork = try sampleSessionData().schedule(for: market("ny"))
        let plan = AlertPlanner.plan(
            schedules: [newYork], from: utc("2026-11-25T22:00:00Z"),
            lead: lead, horizon: 3 * 86_400, limit: 64, viewer: athensTime)
        #expect(plan.map(\.fireDate) == [utc("2026-11-27T14:15:00Z"), utc("2026-11-27T17:45:00Z")])
    }

    @Test func capsTheNumberOfAlertsAndKeepsTheSoonest() {
        let plan = AlertPlanner.plan(
            schedules: Market.all.map { MarketSchedule(market: $0) }, from: utc("2026-09-28T00:00:00Z"),
            lead: lead, horizon: 7 * 86_400, limit: 5, viewer: athensTime)
        #expect(plan.count == 5)
        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())
        // Sydney and Tokyo open at 00:00Z, so their alerts are already past; Hong Kong's is first.
        #expect(plan.first?.fireDate == utc("2026-09-28T01:15:00Z"))
    }
}
