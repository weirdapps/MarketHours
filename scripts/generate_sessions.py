# /// script
# requires-python = ">=3.14"
# dependencies = ["exchange-calendars==4.13.2"]
#
# [tool.uv]
# exclude-newer = "2026-09-28T00:00:00Z"
# ///
"""Generate MarketHours' bundled exchange calendar and its oracle fixture.

    uv run scripts/generate_sessions.py

From exchange_calendars it builds:
1. sessions.json (schema v1): per market, the calendar's regular hours, every
   weekday in coverage that is not a session, and every session whose hours
   differ from the regular ones.
2. oracle_sample.csv: phase and next state change at sampled instants, for the
   Swift tests (semantics in oracle_dump.py).

Then it self-checks, and exits non-zero without writing anything on failure:
1. every session in coverage, rebuilt from the JSON text alone, matches the
   calendar's schedule to the second;
2. the calendar's regular hours and zones match what the app shows (APP_HOURS),
   so an exchange changing its hours fails here, as Tokyo did in 2024;
3. the fixture fits FIXTURE_MAX_BYTES.

Re-running changes nothing but `generatedAt`.
"""

import datetime as dt
import io
import json
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

import exchange_calendars as xc
import numpy as np
import pandas as pd

from oracle_dump import (
    ATHENS_CALENDAR_OPEN,
    MARKETS,
    load_calendar,
    oracle_rows,
    session_intervals,
    to_epoch,
    utc_epoch,
    write_csv,
)

ROOT = Path(__file__).resolve().parent.parent
SESSIONS_JSON = ROOT / "Packages/MarketHoursCore/Sources/MarketHoursCore/Resources/sessions.json"
ORACLE_CSV = ROOT / "Packages/MarketHoursCore/Tests/MarketHoursCoreTests/Fixtures/oracle_sample.csv"

FIRST, LAST = dt.date(2026, 1, 1), dt.date(2028, 12, 31)  # coverage, exchange-local dates

# The hours the app shows: (open, close, breaks), exchange-local. The one
# intended difference from the calendar is the Athens open, 10:30 against the
# calendar's 10:00: see oracle_dump.athens_app_opens().
APP_HOURS = {
    "ny": ("09:30", "16:00", []),
    "london": ("08:00", "16:30", []),
    "frankfurt": ("09:00", "17:30", []),
    "athens": ("10:30", "17:20", []),
    "tokyo": ("09:00", "15:30", [["11:30", "12:30"]]),
    "hongkong": ("09:30", "16:00", [["12:00", "13:00"]]),
    "sydney": ("10:00", "16:00", []),
}

# oracle_sample.csv instants: (a) every holiday and special date in the window,
# plus the weekday before and after each, sampled on the UTC half-hour grid
# across that exchange-local day's trading window: DAY_MARGIN before the regular
# open to DAY_MARGIN after the regular close; (b) a grid for all markets.
# The first spec sampled each date's whole UTC day with a 433-minute grid:
# ~23K rows, ~940 KB, over the cap. Measured, the trading window hits the same
# exact open/close/break boundaries as whole-day sampling (Sydney 30 against 29)
# with under half the rows: the overnight rows it drops only repeat "closed,
# next open". The grid step is prime, so it drifts across minute offsets.
FIXTURE_FIRST, FIXTURE_LAST = dt.date(2026, 10, 1), dt.date(2027, 12, 31)
DAY_STEP_MINUTES = 30
DAY_MARGIN = dt.timedelta(hours=2)
GRID_STEP_MINUTES = 1279
FIXTURE_MAX_BYTES = 400_000


def regular(cal: xc.ExchangeCalendar, times, what: str) -> str | None:
    """The calendar's regular `what` time in effect on FIRST, as "HH:mm". Fails
    loudly if it changes inside coverage."""
    if not times:
        return None
    current = None
    for start, t in sorted(times, key=lambda st: pd.Timestamp.min if st[0] is None else pd.Timestamp(st[0])):
        if start is None or pd.Timestamp(start) <= pd.Timestamp(FIRST):
            current = t
        elif pd.Timestamp(start) <= pd.Timestamp(LAST):
            sys.exit(f"{cal.name}: regular {what} changes to {t:%H:%M} on {start:%Y-%m-%d}, inside coverage")
    if current is None:
        sys.exit(f"{cal.name}: no regular {what} in effect on {FIRST}")
    return f"{current:%H:%M}"


def implied_breaks(breaks: list, open_: str, close: str) -> list:
    """The regular breaks that fit entirely inside [open_, close). Zero-padded
    "HH:mm" strings compare in time order."""
    return [b for b in breaks if open_ <= b[0] and b[1] <= close]


def build_market(market: str, cal: xc.ExchangeCalendar) -> dict:
    code, zone = MARKETS[market]
    if cal.open_offset or cal.close_offset:
        sys.exit(f"{code}: sessions span calendar days, which schema v1 cannot express")
    break_start = regular(cal, cal.break_start_times, "break start")
    break_end = regular(cal, cal.break_end_times, "break end")
    reg = {
        "open": regular(cal, cal.open_times, "open"),
        "close": regular(cal, cal.close_times, "close"),
        "breaks": [[break_start, break_end]] if break_start else [],
    }

    first, last = pd.Timestamp(FIRST), pd.Timestamp(LAST)
    names: dict[str, list[str]] = {}
    if cal.regular_holidays is not None:
        for day, name in cal.regular_holidays.holidays(first, last, return_name=True).items():
            names.setdefault(f"{day:%Y-%m-%d}", []).append(name)
    sched = cal.schedule.loc[first:last]
    holidays = {}
    for day in pd.bdate_range(first, last).difference(sched.index):
        key = f"{day:%Y-%m-%d}"
        # Rules can repeat a name on one date (ASEX lists western and Orthodox
        # Good Friday; in 2028 they coincide). Adhoc closures have no name.
        holidays[key] = " / ".join(dict.fromkeys(names.get(key, []))) or "Holiday"

    special = {}
    local = sched.apply(lambda col: col.dt.tz_convert(cal.tz))
    for day, row in local.iterrows():
        open_, close = f"{row['open']:%H:%M}", f"{row['close']:%H:%M}"
        breaks = [] if pd.isna(row["break_start"]) else [[f"{row['break_start']:%H:%M}", f"{row['break_end']:%H:%M}"]]
        entry = {}
        if open_ != reg["open"]:
            entry["open"] = open_
        if close != reg["close"]:
            entry["close"] = close
        if breaks != implied_breaks(reg["breaks"], open_, close):
            entry["breaks"] = breaks
        if entry:
            special[f"{day:%Y-%m-%d}"] = entry
    return {"calendar": code, "timeZone": zone, "calendarRegular": reg, "holidays": holidays, "special": special}


def local_epoch(day: dt.date, hhmm: str | None, zone: ZoneInfo) -> int:
    """Exchange-local "HH:mm" on `day` -> UTC epoch seconds; -1 for None."""
    if hhmm is None:
        return -1
    return int(dt.datetime.combine(day, dt.time.fromisoformat(hhmm), tzinfo=zone).timestamp())


def check_rebuild(data: dict, cals: dict) -> int:
    """Self-check 1. Rebuild every session in coverage from the JSON alone
    (Mon-Fri, not a holiday; open and close from calendarRegular overridden by
    special; breaks from special, else implied) and compare it in UTC with the
    calendar's schedule. Returns the number of mismatching dates."""
    print(f"self-check 1: sessions rebuilt from sessions.json vs exchange_calendars, {FIRST}..{LAST}")
    total = 0
    for market, m in data["markets"].items():
        reg, holidays, special = m["calendarRegular"], m["holidays"], m["special"]
        zone = ZoneInfo(m["timeZone"])
        rebuilt = {}
        day = FIRST
        while day <= LAST:
            key = day.isoformat()
            if day.weekday() < 5 and key not in holidays:
                sp = special.get(key, {})
                open_, close = sp.get("open", reg["open"]), sp.get("close", reg["close"])
                breaks = sp["breaks"] if "breaks" in sp else implied_breaks(reg["breaks"], open_, close)
                if len(breaks) > 1:
                    raise ValueError(f"{market} {key}: exchange_calendars models at most one break")
                break_start, break_end = breaks[0] if breaks else (None, None)
                rebuilt[key] = tuple(local_epoch(day, t, zone) for t in (open_, close, break_start, break_end))
            day += dt.timedelta(days=1)

        sched = cals[market].schedule.loc[pd.Timestamp(FIRST) : pd.Timestamp(LAST)]
        columns = (to_epoch(sched[k]).tolist() for k in ("open", "close", "break_start", "break_end"))
        actual = dict(zip((f"{d:%Y-%m-%d}" for d in sched.index), zip(*columns, strict=True), strict=True))
        mismatches = [k for k in sorted(rebuilt.keys() | actual.keys()) if rebuilt.get(k) != actual.get(k)]
        total += len(mismatches)
        print(
            f"  {market:<10} {m['calendar']}  sessions {len(actual):4}  mismatches {len(mismatches)}"
            f"  (holidays {len(holidays)}, special {len(special)})"
        )
        for key in mismatches[:5]:
            print(f"    {key}: json {rebuilt.get(key)}  calendar {actual.get(key)}")
    return total


def check_app_hours(data: dict, cals: dict) -> int:
    """Self-check 2. calendarRegular and the zone equal what the app shows,
    except the documented Athens open. Returns the number of failing markets."""
    print("self-check 2: calendarRegular vs the hours the app shows")
    failures = 0
    for market, (open_, close, breaks) in APP_HOURS.items():
        m = data["markets"][market]
        expected = {"open": open_, "close": close, "breaks": breaks, "timeZone": m["timeZone"]}
        actual = {**m["calendarRegular"], "timeZone": str(cals[market].tz)}
        note = ""
        if market == "athens":
            expected["open"] = ATHENS_CALENDAR_OPEN
            note = f"  (calendar opens {ATHENS_CALENDAR_OPEN}, app {open_}: documented exception)"
        diffs = {k: f"calendar {actual[k]}, expected {expected[k]}" for k in expected if actual[k] != expected[k]}
        failures += bool(diffs)
        print(f"  {market:<10} {'FAIL ' + str(diffs) if diffs else 'ok'}{note}")
    return failures


def adjacent_weekday(day: dt.date, step: int) -> dt.date:
    day += dt.timedelta(days=step)
    while day.weekday() >= 5:
        day += dt.timedelta(days=step)
    return day


def trading_window(day: dt.date, reg: dict, zone: ZoneInfo) -> np.ndarray:
    """Instants on the UTC DAY_STEP_MINUTES grid from DAY_MARGIN before the
    regular open to DAY_MARGIN after the regular close of `day`, exchange-local."""
    step, margin = DAY_STEP_MINUTES * 60, int(DAY_MARGIN.total_seconds())
    start = local_epoch(day, reg["open"], zone) - margin
    end = local_epoch(day, reg["close"], zone) + margin
    return np.arange(-(-start // step) * step, end + 1, step)


def fixture_epochs(data: dict) -> dict[str, np.ndarray]:
    """Per market, the sorted unique instants of oracle_sample.csv."""
    grid = np.arange(utc_epoch(FIXTURE_FIRST), utc_epoch(FIXTURE_LAST + dt.timedelta(days=1)), GRID_STEP_MINUTES * 60)
    lo, hi = FIXTURE_FIRST.isoformat(), FIXTURE_LAST.isoformat()
    epochs = {}
    for market, m in data["markets"].items():
        days = {dt.date.fromisoformat(k) for k in (*m["holidays"], *m["special"]) if lo <= k <= hi}
        days |= {adjacent_weekday(d, -1) for d in days} | {adjacent_weekday(d, 1) for d in days}
        zone = ZoneInfo(m["timeZone"])
        windows = [trading_window(d, m["calendarRegular"], zone) for d in days]
        epochs[market] = np.unique(np.concatenate([grid, *windows]))
    return epochs


def main() -> None:
    cals = {market: load_calendar(code, FIRST, LAST) for market, (code, _) in MARKETS.items()}
    data = {
        "schemaVersion": 1,
        "generatedAt": dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": f"exchange_calendars {xc.__version__}",
        "coverage": {"first": FIRST.isoformat(), "last": LAST.isoformat()},
        "markets": {market: build_market(market, cals[market]) for market in MARKETS},
    }
    sessions_text = json.dumps(data, indent=2, sort_keys=True) + "\n"
    parsed = json.loads(sessions_text)
    failures = check_rebuild(parsed, cals) + check_app_hours(parsed, cals)

    rows = oracle_rows(fixture_epochs(parsed), {market: session_intervals(market, cals[market]) for market in MARKETS})
    buf = io.StringIO()
    write_csv(rows, buf)
    fixture_text = buf.getvalue()
    size = len(fixture_text.encode())
    phases = pd.Series([r[2] for r in rows]).value_counts().to_dict()
    print(f"self-check 3: oracle_sample.csv {len(rows)} rows, {size} bytes (max {FIXTURE_MAX_BYTES}), phases {phases}")
    failures += size > FIXTURE_MAX_BYTES

    if failures:
        sys.exit(f"FAILED: {failures} self-check failure(s); nothing written")
    for path, text in ((SESSIONS_JSON, sessions_text), (ORACLE_CSV, fixture_text)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
