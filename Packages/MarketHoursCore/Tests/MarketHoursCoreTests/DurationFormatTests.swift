import Testing
@testable import MarketHoursCore

@Suite struct DurationFormatTests {
    // Countdowns round UP: "1s" means at most one second to go, never "0s" before the event.
    @Test(arguments: [
        (0.4, "1s"), (9.4, "10s"), (59.2, "1m 00s"), (65.0, "1m 05s"),
        (3_599.2, "1h 00m 00s"), (22_500.0, "6h 15m 00s"), (23_399.6, "6h 30m 00s"),
        (231_000.0, "2d 16h 10m"), (231_001.0, "2d 16h 11m"),
    ])
    func panelFormat(seconds: Double, expected: String) {
        #expect(DurationFormat.long(seconds) == expected)
    }

    @Test(arguments: [
        (1_200.0, false, "20m"), (1_141.0, false, "20m"), (42.0, false, "1m"),
        (3_570.0, false, "1h00m"), (7_500.0, false, "2h05m"), (86_399.0, false, "1d00h"),
        (136_800.0, false, "1d14h"), (1_182.0, true, "19m42s"), (42.0, true, "42s"),
        (3_600.0, true, "1h00m"), (7_500.0, true, "2h05m"),
    ])
    func menuBarFormat(seconds: Double, showSeconds: Bool, expected: String) {
        #expect(DurationFormat.compact(seconds, showSeconds: showSeconds) == expected)
    }
}
