# Market Hours

A small macOS menu bar app that counts down to the next **open** and **close** of seven equity markets, with exchange holidays, early closes and lunch breaks.

## Markets

| Market | Time zone | Regular session (local time) |
|--------|-----------|------------------------------|
| New York (NYSE / Nasdaq) | America/New_York | 09:30-16:00 |
| London (LSE) | Europe/London | 08:00-16:30 |
| Frankfurt (Xetra) | Europe/Berlin | 09:00-17:30 |
| Athens (Euronext Athens) | Europe/Athens | 10:30-17:20 |
| Tokyo (TSE) | Asia/Tokyo | 09:00-11:30, 12:30-15:30 |
| Hong Kong (HKEX) | Asia/Hong_Kong | 09:30-12:00, 13:00-16:00 |
| Sydney (ASX) | Australia/Sydney | 10:00-16:00 |

Athens opens at 10:30, when continuous trading starts after the 10:15 call auction, and closes at 17:20, when trading at the closing price ends. Tokyo has closed at 15:30 since 5 November 2024.

Holidays and early closes come from [exchange_calendars](https://github.com/gerrymanoim/exchange_calendars), exported to a JSON file inside the app, so nothing is fetched at run time. The bundled data runs to 31 December 2028; after that the app treats every weekday as a regular session, and it warns in the panel 60 days before the data runs out.

## What it shows

- **Menu bar:** the next event across the markets you show, as `▲NY 5m` (opens) or `▼LON 2h05m` (closes or breaks for lunch). Pin one market instead in Settings, and optionally show seconds. Digits are tabular, so the item keeps its width.
- **Panel:** every shown market, soonest event first, with its local clock, a countdown, today's session in your own time zone, holidays by name, and a progress bar that turns orange in the last 15 minutes before the close.
- **Settings** (gear icon, or ⌘, in the panel): which markets to show, the menu bar countdown, alerts, and launch at login.
- **Alerts:** a notification 5, 10, 15 or 30 minutes before a market opens or closes. Turn them on per market with the bell icon.

## Requirements

- macOS 14 or later
- Xcode 16 or later (Swift 6). Xcode 27 works.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), to regenerate the project after editing `project.yml`

## Run

```bash
# HTTPS (no SSH key required):
git clone https://github.com/weirdapps/MarketHours.git
# or, with SSH:
git clone git@github.com:weirdapps/MarketHours.git

cd MarketHours
xcodegen generate
open MarketHours.xcodeproj   # then pick the MarketHours scheme and press ⌘R
```

The app lives in the menu bar only (no Dock icon). Quit from the panel's **Quit** button or ⌘Q while the panel is open.

To install a release build:

```bash
xcodebuild -project MarketHours.xcodeproj -scheme MarketHours -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/MarketHours.app /Applications/
```

Turn on **Launch at login** from the copy in /Applications, not from a debug build.

## Test

The schedule logic lives in `Packages/MarketHoursCore`, free of AppKit and SwiftUI, so it tests from the command line and on Linux in CI:

```bash
swift test --package-path Packages/MarketHoursCore
```

The tests cover lunch breaks, daylight-saving changes, holidays, early closes, countdown rounding, the menu bar pick and alert planning, and compare the app against an exchange_calendars sample (`Tests/MarketHoursCoreTests/Fixtures/oracle_sample.csv`).

## Refresh the holiday data

Once a year, or when an exchange changes its hours:

```bash
uv run scripts/generate_sessions.py
```

This regenerates `Packages/MarketHoursCore/Sources/MarketHoursCore/Resources/sessions.json` and the oracle sample. It exits non-zero if the file does not reproduce every exchange_calendars session, or if an exchange's regular hours no longer match the hours the app shows. The script keeps its own copy of those hours (`APP_HOURS`); the Swift test `appHoursMatchTheCalendarExceptTheAthensOpen` checks `Market.swift` against the same data, so changing one copy without the other fails loudly. Commit both files, then run the tests.

## Icon

`swift scripts/make_icon.swift` redraws every size of the app icon into `MarketHours/Assets.xcassets/AppIcon.appiconset`.
