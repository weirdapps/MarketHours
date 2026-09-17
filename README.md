# Market Hours

A simple, beautiful macOS menu bar app that shows **time to open** and **time to close** for major equity markets.

## Markets

| Market | Time zone | Regular session |
|--------|-----------|-----------------|
| New York (NYSE / Nasdaq) | America/New_York | 09:30–16:00 |
| London (LSE) | Europe/London | 08:00–16:30 |
| Frankfurt (Xetra) | Europe/Berlin | 09:00–17:30 |
| Tokyo (TSE) | Asia/Tokyo | 09:00–15:00 |
| Hong Kong (HKEX) | Asia/Hong_Kong | 09:30–16:00 |
| Sydney (ASX) | Australia/Sydney | 10:00–16:00 |

Weekends are treated as closed (each market’s local calendar). Exchange holidays are not modeled.

## Requirements

- macOS 14 or later
- Xcode 15+ (Xcode 27 works)

## Run

1. Open `MarketHours.xcodeproj` in Xcode  
   (If the project file is missing, run `xcodegen generate` from this folder — [XcodeGen](https://github.com/yonaskolb/XcodeGen) required.)
2. Select the **MarketHours** scheme
3. Press **⌘R**

The app appears in the menu bar only (no Dock icon). Click the chart icon to open the panel.

## Quit

Use **Quit** at the bottom of the panel, or Force Quit from Activity Monitor.

## Notes

- Countdowns update every second
- All times use the market’s IANA time zone (DST handled automatically)
- No network access or API keys required
