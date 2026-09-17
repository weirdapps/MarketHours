import Foundation

struct Market: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let flag: String
    let timeZoneIdentifier: String
    let openHour: Int
    let openMinute: Int
    let closeHour: Int
    let closeMinute: Int

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .gmt
    }

    static let all: [Market] = [
        Market(
            id: "ny",
            name: "New York",
            shortName: "NY",
            flag: "🇺🇸",
            timeZoneIdentifier: "America/New_York",
            openHour: 9, openMinute: 30,
            closeHour: 16, closeMinute: 0
        ),
        Market(
            id: "london",
            name: "London",
            shortName: "LON",
            flag: "🇬🇧",
            timeZoneIdentifier: "Europe/London",
            openHour: 8, openMinute: 0,
            closeHour: 16, closeMinute: 30
        ),
        Market(
            id: "frankfurt",
            name: "Frankfurt",
            shortName: "FRA",
            flag: "🇩🇪",
            timeZoneIdentifier: "Europe/Berlin",
            openHour: 9, openMinute: 0,
            closeHour: 17, closeMinute: 30
        ),
        Market(
            id: "tokyo",
            name: "Tokyo",
            shortName: "TYO",
            flag: "🇯🇵",
            timeZoneIdentifier: "Asia/Tokyo",
            openHour: 9, openMinute: 0,
            closeHour: 15, closeMinute: 0
        ),
        Market(
            id: "hongkong",
            name: "Hong Kong",
            shortName: "HK",
            flag: "🇭🇰",
            timeZoneIdentifier: "Asia/Hong_Kong",
            openHour: 9, openMinute: 30,
            closeHour: 16, closeMinute: 0
        ),
        Market(
            id: "sydney",
            name: "Sydney",
            shortName: "SYD",
            flag: "🇦🇺",
            timeZoneIdentifier: "Australia/Sydney",
            openHour: 10, openMinute: 0,
            closeHour: 16, closeMinute: 0
        )
    ]
}

enum MarketStatus: Equatable {
    case open
    case closed
}

struct MarketSnapshot: Identifiable {
    var id: String { market.id }
    let market: Market
    let status: MarketStatus
    let localTime: Date
    let countdown: TimeInterval
    let countdownLabel: String
    let sessionProgress: Double?
    let nextEventIsClose: Bool
}
