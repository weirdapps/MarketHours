# MarketHours

SwiftUI macOS menu-bar app showing time-to-open and time-to-close for six equity markets.
`LSUIElement` (no Dock icon), no network, no dependencies. Default branch `main`.
`README.md` covers the markets table and how to run from Xcode.

## Build

    xcodegen generate                                                   # after ANY project.yml edit
    xcodebuild -project MarketHours.xcodeproj -scheme MarketHours build

`xcodegen` is at `/opt/homebrew/bin/xcodegen` (2.46.0), so it is missing from a subagent's
sanitized PATH. Call it through `zsh -lc` or by absolute path before believing "not found".

## Traps

- **`project.yml` is the source of truth. `MarketHours.xcodeproj` is generated output** that
  happens to be committed. Hand-editing the pbxproj works until the next `xcodegen
  generate` silently discards it. Change build settings in `project.yml`.
- New Swift files under `MarketHours/` are picked up by the `sources:` path automatically,
  but only after regenerating. A file that compiles in your editor and not in Xcode means
  you skipped `xcodegen generate`.
- **After an Xcode major upgrade, every `xcrun`-backed tool fails** with "You have not
  agreed to the Xcode license agreements", including `/usr/bin/git`. One-time fix:
  `sudo xcodebuild -license accept`. This already broke an unrelated launchd job on this
  Mac, so treat it as an estate-wide gate, not a MarketHours one.
- Ad-hoc signing only (`CODE_SIGN_IDENTITY: "-"`, hardened runtime on). There is no team,
  no notarization and no distribution path. Do not add one unasked.
- **There are no tests and no CI.** Nothing catches a regression but running the app, so
  verify changes by building and launching, not by claiming they compile.
- Exchange holidays are deliberately not modelled, only weekends. Do not describe the app
  as holiday-aware, and do not add a holiday calendar without asking.

## Layout

    MarketHours/Models/Market.swift        market definitions, IANA zones, session times
    MarketHours/Services/MarketClock.swift countdown logic, DST handled by TimeZone
    MarketHours/Views/MarketPanelView.swift the panel
    MarketHoursApp.swift                   MenuBarExtra entry point
