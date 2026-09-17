import Combine
import Foundation
import SwiftUI

@MainActor
final class MarketClock: ObservableObject {
    @Published private(set) var now: Date = Date()
    @Published private(set) var snapshots: [MarketSnapshot] = []
    @Published private(set) var menuBarSubtitle: String = ""

    private var timer: AnyCancellable?
    private let localTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        refresh()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
                self?.refresh()
            }
    }

    func formattedLocalTime(for market: Market) -> String {
        localTimeFormatter.timeZone = market.timeZone
        return localTimeFormatter.string(from: now)
    }

    private func refresh() {
        snapshots = Market.all.map { snapshot(for: $0, at: now) }
        menuBarSubtitle = headlineSubtitle(from: snapshots)
    }

    private func headlineSubtitle(from snapshots: [MarketSnapshot]) -> String {
        // Prefer soonest close among open markets; else soonest open.
        let openOnes = snapshots.filter { $0.status == .open }
        if let soonest = openOnes.min(by: { $0.countdown < $1.countdown }) {
            return "\(soonest.market.shortName) \(formatCompact(soonest.countdown))"
        }
        if let soonest = snapshots.min(by: { $0.countdown < $1.countdown }) {
            return "\(soonest.market.shortName) \(formatCompact(soonest.countdown))"
        }
        return ""
    }

    private func snapshot(for market: Market, at date: Date) -> MarketSnapshot {
        let cal = Calendar.current
        var calTZ = cal
        calTZ.timeZone = market.timeZone

        let localComponents = calTZ.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)
        let weekday = localComponents.weekday ?? 1 // 1=Sun ... 7=Sat
        let isWeekend = weekday == 1 || weekday == 7

        let openDate = dateOnDay(calTZ, from: localComponents, hour: market.openHour, minute: market.openMinute)
        let closeDate = dateOnDay(calTZ, from: localComponents, hour: market.closeHour, minute: market.closeMinute)

        if !isWeekend, date >= openDate, date < closeDate {
            let remaining = closeDate.timeIntervalSince(date)
            let total = closeDate.timeIntervalSince(openDate)
            let progress = total > 0 ? min(max(1 - remaining / total, 0), 1) : 0
            return MarketSnapshot(
                market: market,
                status: .open,
                localTime: date,
                countdown: remaining,
                countdownLabel: "Closes in \(formatDuration(remaining))",
                sessionProgress: progress,
                nextEventIsClose: true
            )
        }

        let nextOpen = nextOpenDate(for: market, after: date, calendar: calTZ)
        let remaining = nextOpen.timeIntervalSince(date)
        return MarketSnapshot(
            market: market,
            status: .closed,
            localTime: date,
            countdown: remaining,
            countdownLabel: "Opens in \(formatDuration(remaining))",
            sessionProgress: nil,
            nextEventIsClose: false
        )
    }

    private func nextOpenDate(for market: Market, after date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.timeZone = market.timeZone
        let components = cal.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        let todayOpen = dateOnDay(cal, from: components, hour: market.openHour, minute: market.openMinute)
        let weekday = components.weekday ?? 1
        let isWeekend = weekday == 1 || weekday == 7

        if !isWeekend, date < todayOpen {
            return todayOpen
        }

        // Walk forward day by day to next weekday open.
        var candidate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date)) ?? date
        for _ in 0..<8 {
            let wd = cal.component(.weekday, from: candidate)
            if wd != 1 && wd != 7 {
                var openComponents = cal.dateComponents([.year, .month, .day], from: candidate)
                openComponents.hour = market.openHour
                openComponents.minute = market.openMinute
                openComponents.second = 0
                if let open = cal.date(from: openComponents) {
                    return open
                }
            }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return todayOpen
    }

    private func dateOnDay(_ calendar: Calendar, from components: DateComponents, hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = components.year
        c.month = components.month
        c.day = components.day
        c.hour = hour
        c.minute = minute
        c.second = 0
        return calendar.date(from: c) ?? Date()
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func formatCompact(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes)m\(seconds)s"
        }
        return "\(seconds)s"
    }
}
