# MarketHours

SwiftUI macOS menu-bar app counting down to the next open and close of seven equity markets,
with holidays, early closes and lunch breaks. `LSUIElement` (no Dock icon), no network at run
time, no third-party Swift dependencies. Default branch `main`. `README.md` covers the markets
table, running, installing and refreshing the data.

## Build and test

    xcodegen generate                                                   # after ANY project.yml edit
    xcodebuild -project MarketHours.xcodeproj -scheme MarketHours build
    swift test --package-path Packages/MarketHoursCore                  # the logic, ~1 s

`xcodegen` is at `/opt/homebrew/bin/xcodegen` (2.46.0), so it is missing from a subagent's
sanitized PATH. Call it through `zsh -lc` or by absolute path before believing "not found".

## Traps

- **`project.yml` is the source of truth. `MarketHours.xcodeproj` is generated output** that
  happens to be committed. Hand-editing the pbxproj works until the next `xcodegen
  generate` silently discards it. Change build settings in `project.yml`. There is no
  Info.plist file: every key is an `INFOPLIST_KEY_*` setting there.
- New Swift files under `MarketHours/` are picked up by the `sources:` path automatically,
  but only after regenerating. A file that compiles in your editor and not in Xcode means
  you skipped `xcodegen generate`.
- **Schedule logic belongs in `Packages/MarketHoursCore`**, which must stay Foundation-only:
  CI runs its tests on Linux (`.github/workflows/tests.yml`). The app target is UI only.
  Write the failing test first; expected instants are worked out by hand, never computed
  with the code under test.
- **`sessions.json` is generated.** Never hand-edit it: rerun `uv run scripts/generate_sessions.py`,
  which also rewrites the oracle fixture and fails if the data does not reproduce every
  exchange_calendars session. Coverage ends 2028-12-31; the app warns 60 days ahead and
  falls back to weekdays after.
- **The app's hours live in two places on purpose**: `Market.swift` and `APP_HOURS` in
  `scripts/generate_sessions.py`. The generator checks its copy against exchange_calendars,
  `BundledDataTests.appHoursMatchTheCalendarExceptTheAthensOpen` checks the Swift one, so
  changing one without the other fails loudly. Change both.
- **Athens differs from exchange_calendars on purpose**: the app opens ASEX at 10:30
  (continuous trading), the calendar at 10:00. The generator and the tests both allow for
  exactly that difference and nothing else.
- **The menu bar label is an NSImage that draws itself on demand** (`MenuBarLabelRenderer`).
  Tabular digits, because SwiftUI ignores `.monospacedDigit()` in a MenuBarExtra label and a
  Text label changed the item's width every second. Not a template, because a template
  turns the flag into a solid shape; the ink is `labelColor`, resolved against the
  appearance it is drawn in, so it follows a light or dark menu bar. Do not switch it back
  to Text or to a template image.
- **A closed panel must cost nothing.** The per-second clock runs only while the panel is on
  screen (`WindowVisibilityReader` plus a self-check on each tick); the menu bar updates on
  the minute. v1 burned 1.3% CPU around the clock redrawing a hidden panel. After touching
  the tickers, measure: `ps -o time= -p <pid>` over 60 s should not move.
- The MenuBarExtra status button ignores `performClick` and synthetic mouse events, so the
  panel cannot be opened from inside the app. Debug builds accept `-MHWindowTest` (panel in
  an ordinary window, shown then hidden) and `-MHShowSettings` instead.
- **After an Xcode major upgrade, every `xcrun`-backed tool fails** with "You have not
  agreed to the Xcode license agreements", including `/usr/bin/git`. One-time fix:
  `sudo xcodebuild -license accept`. This already broke an unrelated launchd job on this
  Mac, so treat it as an estate-wide gate, not a MarketHours one.
- Ad-hoc signing only (`CODE_SIGN_IDENTITY: "-"`, hardened runtime on). There is no team,
  no notarization and no distribution path. Do not add one unasked.
- **Launch at login registers whichever copy is running.** Toggle it from /Applications,
  never from a DerivedData build, or the login item points at a build folder.

## Layout

    Packages/MarketHoursCore/Sources/MarketHoursCore/
      Market.swift            the seven markets, regular hours and lunch breaks
      MarketSchedule.swift    status, next event, events in a range, session in viewer time
      SessionData.swift       sessions.json: holidays and special sessions by exchange-local date
      Headline.swift          which countdown the menu bar shows, and its text
      AlertPlanner.swift      notification times and wording
      DurationFormat.swift    countdown text, always rounded up
    MarketHours/
      MarketHoursApp.swift    MenuBarExtra entry point
      Models/AppModel.swift   tickers, menu bar image, panel clock, alerts, system events
      Models/Settings.swift   persisted choices
      Services/               ticker, label renderer, notifications, login item
      Views/                  panel, rows, settings, window visibility
    scripts/generate_sessions.py   exchange_calendars to sessions.json plus oracle fixture
    scripts/oracle_dump.py         dense exchange_calendars dump for one-off comparisons
    scripts/make_icon.swift        redraws the app icon
