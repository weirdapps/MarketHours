# /// script
# requires-python = ">=3.14"
# dependencies = ["exchange-calendars==4.13.2"]
#
# [tool.uv]
# exclude-newer = "2026-09-28T00:00:00Z"
# ///
"""Dense oracle dump: every market's phase and next state change on a fixed grid.

    uv run scripts/oracle_dump.py --start 2026-01-01 --end 2028-12-31 --step-minutes 17 > dump.csv

Instants run from --start 00:00 UTC in --step-minutes steps up to, not including,
the day after --end at 00:00 UTC. Rows are sorted by epoch, then market id.

Columns `epoch,market,phase,next_epoch,next_kind`, computed straight from
exchange_calendars, never from sessions.json:
- epoch: the instant, integer UTC seconds.
- phase: open on [open, close), break on [break_start, break_end), else closed.
- next_epoch, next_kind: the next state change strictly after epoch. When open,
  a later break_start in the same session (break_start), else the close (close);
  in a break, its end (break_end); when closed, the next session's open (open).

Athens convention: the app shows ASEX from 10:30, not the calendar's 10:00. See
athens_app_opens(). generate_sessions.py imports this module to build the
committed oracle_sample.csv with the same semantics.
"""

import argparse
import datetime as dt
import itertools
import sys

import exchange_calendars as xc
import numpy as np
import pandas as pd

# app id -> (exchange_calendars code, IANA zone)
MARKETS = {
    "ny": ("XNYS", "America/New_York"),
    "london": ("XLON", "Europe/London"),
    "frankfurt": ("XETR", "Europe/Berlin"),
    "athens": ("ASEX", "Europe/Athens"),
    "tokyo": ("XTKS", "Asia/Tokyo"),
    "hongkong": ("XHKG", "Asia/Hong_Kong"),
    "sydney": ("XASX", "Australia/Sydney"),
}

ATHENS_CALENDAR_OPEN = "10:00"
ATHENS_APP_DELAY = pd.Timedelta(minutes=30)

CSV_HEADER = "epoch,market,phase,next_epoch,next_kind\n"
EPOCH = pd.Timestamp(0, tz="UTC")


def load_calendar(code: str, first: dt.date, last: dt.date) -> xc.ExchangeCalendar:
    """The calendar with a margin around [first, last], so that every instant in
    those UTC days has its current session and its next open loaded."""
    return xc.get_calendar(code, start=first - dt.timedelta(days=30), end=last + dt.timedelta(days=60))


def to_epoch(ts: pd.Series) -> np.ndarray:
    """tz-aware timestamps -> int64 UTC epoch seconds, -1 where NaT."""
    return ((ts - EPOCH) // pd.Timedelta(seconds=1)).fillna(-1).astype("int64").to_numpy()


def athens_app_opens(opens: pd.Series, tz) -> pd.Series:
    """Athens convention. exchange_calendars opens ASEX at 10:00, but the official
    Euronext Athens Cash Markets Schedule (March 2026) runs a call auction
    10:15-10:30 and continuous trading from 10:30, which is what the app shows.
    So a session whose calendar open is the regular 10:00 opens at 10:30 local
    instead: 10:00-10:29 is closed, with next open 10:30. Any other (special)
    open is kept. Adding 30 minutes in UTC is exact: no DST change falls at 10:00."""
    regular = opens.dt.tz_convert(tz).dt.strftime("%H:%M") == ATHENS_CALENDAR_OPEN
    return opens.where(~regular, opens + ATHENS_APP_DELAY)


def session_intervals(market: str, cal: xc.ExchangeCalendar) -> tuple[np.ndarray, ...]:
    """(open, close, break_start, break_end) per session of `cal`, as int64 UTC
    epoch seconds in session order; the break pair is -1 when there is none."""
    s = cal.schedule
    opens = athens_app_opens(s["open"], cal.tz) if market == "athens" else s["open"]
    o, c, bs, be = (to_epoch(col) for col in (opens, s["close"], s["break_start"], s["break_end"]))
    has_break = bs >= 0
    ordered = (o < c).all() and (c[:-1] <= o[1:]).all()
    breaks_inside = ((be >= 0) == has_break).all() and ((o < bs) & (bs < be) & (be < c))[has_break].all()
    if not (ordered and breaks_inside):
        raise ValueError(f"{cal.name}: sessions overlap or a break falls outside its session")
    return o, c, bs, be


def classify(epochs: np.ndarray, o, c, bs, be) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """phase, next_epoch, next_kind at each instant, per the module docstring."""
    i = np.searchsorted(o, epochs, side="right") - 1  # last session opening at or before t
    if (i < 0).any():
        raise ValueError("instant before the first loaded session")
    in_session = epochs < c[i]
    has_break = bs[i] >= 0
    in_break = in_session & has_break & (bs[i] <= epochs) & (epochs < be[i])
    is_open = in_session & ~in_break
    before_break = is_open & has_break & (epochs < bs[i])
    j = i + 1  # first session opening after t
    if (~in_session & (j >= len(o))).any():
        raise ValueError("instant after the last loaded session")
    next_open = o[np.minimum(j, len(o) - 1)]
    phase = np.select([is_open, in_break], ["open", "break"], "closed")
    next_epoch = np.select([before_break, is_open, in_break], [bs[i], c[i], be[i]], next_open)
    next_kind = np.select([before_break, is_open, in_break], ["break_start", "close", "break_end"], "open")
    return phase, next_epoch, next_kind


def oracle_rows(market_epochs: dict[str, np.ndarray], intervals: dict[str, tuple]) -> list[tuple]:
    """(epoch, market, phase, next_epoch, next_kind) rows, sorted by epoch then market."""
    rows = []
    for market, epochs in market_epochs.items():
        phase, next_epoch, next_kind = classify(epochs, *intervals[market])
        rows.extend(
            zip(epochs.tolist(), itertools.repeat(market), phase.tolist(), next_epoch.tolist(), next_kind.tolist())
        )
    rows.sort(key=lambda r: (r[0], r[1]))
    return rows


def write_csv(rows: list[tuple], out) -> None:
    out.write(CSV_HEADER)
    out.writelines(f"{e},{m},{p},{n},{k}\n" for e, m, p, n, k in rows)


def utc_epoch(day: dt.date) -> int:
    return int(dt.datetime.combine(day, dt.time(), tzinfo=dt.UTC).timestamp())


def main() -> None:
    parser = argparse.ArgumentParser(description="Dense oracle dump for all 7 markets, CSV to stdout.")
    parser.add_argument("--start", required=True, type=dt.date.fromisoformat, help="first UTC day, YYYY-MM-DD")
    parser.add_argument("--end", required=True, type=dt.date.fromisoformat, help="last UTC day, YYYY-MM-DD")
    parser.add_argument("--step-minutes", required=True, type=int)
    args = parser.parse_args()
    if args.end < args.start or args.step_minutes <= 0:
        parser.error("need --start <= --end and --step-minutes > 0")

    epochs = np.arange(utc_epoch(args.start), utc_epoch(args.end + dt.timedelta(days=1)), args.step_minutes * 60)
    intervals = {
        market: session_intervals(market, load_calendar(code, args.start, args.end))
        for market, (code, _) in MARKETS.items()
    }
    write_csv(oracle_rows({market: epochs for market in MARKETS}, intervals), sys.stdout)


if __name__ == "__main__":
    main()
