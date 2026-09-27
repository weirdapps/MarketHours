import Foundation
@testable import MarketHoursCore

func utc(_ string: String) -> Date {
    guard let date = ISO8601DateFormatter().date(from: string) else {
        fatalError("bad test timestamp \(string)")
    }
    return date
}

func market(_ id: String) -> Market {
    guard let market = Market.all.first(where: { $0.id == id }) else {
        fatalError("unknown market \(id)")
    }
    return market
}

func schedule(_ id: String) -> MarketSchedule {
    MarketSchedule(market: market(id))
}

let athensTime = TimeZone(identifier: "Europe/Athens")!

/// Hand-written session data in the sessions.json shape. Coverage ends 2026-12-31.
let sampleSessionJSON = """
{
  "schemaVersion": 1,
  "generatedAt": "2026-09-28T00:00:00Z",
  "source": "hand-written test data",
  "coverage": { "first": "2026-01-01", "last": "2026-12-31" },
  "markets": {
    "ny": {
      "calendar": "XNYS",
      "timeZone": "America/New_York",
      "calendarRegular": { "open": "09:30", "close": "16:00", "breaks": [] },
      "holidays": { "2026-11-26": "Thanksgiving" },
      "special": { "2026-11-27": { "close": "13:00" } }
    },
    "hongkong": {
      "calendar": "XHKG",
      "timeZone": "Asia/Hong_Kong",
      "calendarRegular": { "open": "09:30", "close": "16:00", "breaks": [["12:00", "13:00"]] },
      "holidays": {},
      "special": { "2026-12-24": { "close": "12:00" } }
    }
  }
}
"""

func sampleSessionData() throws -> SessionData {
    try SessionData(jsonData: Data(sampleSessionJSON.utf8))
}
