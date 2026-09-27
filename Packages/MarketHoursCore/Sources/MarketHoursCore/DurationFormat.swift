import Foundation

/// Countdown text. Everything rounds UP, so a countdown never reads zero before its event.
public enum DurationFormat {
    /// Panel format: "6h 05m 03s", "5m 03s", "3s", or "2d 04h 30m" from a day out.
    public static func long(_ seconds: TimeInterval) -> String {
        let total = wholeSecondsUp(seconds)
        if total >= 86_400 {
            let minutes = (total + 59) / 60
            return "\(minutes / 1_440)d \(twoDigits(minutes % 1_440 / 60))h \(twoDigits(minutes % 60))m"
        }
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let secs = total % 60
        if hours > 0 { return "\(hours)h \(twoDigits(minutes))m \(twoDigits(secs))s" }
        if minutes > 0 { return "\(minutes)m \(twoDigits(secs))s" }
        return "\(secs)s"
    }

    /// Menu bar format: "20m", "2h05m", "1d14h", or with seconds "19m42s" under an hour.
    public static func compact(_ seconds: TimeInterval, showSeconds: Bool) -> String {
        let total = wholeSecondsUp(seconds)
        if showSeconds && total < 3_600 {
            let minutes = total / 60
            return minutes > 0 ? "\(minutes)m\(twoDigits(total % 60))s" : "\(total)s"
        }
        let minutes = (total + 59) / 60
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1_440 { return "\(minutes / 60)h\(twoDigits(minutes % 60))m" }
        let hours = (total + 3_599) / 3_600
        return "\(hours / 24)d\(twoDigits(hours % 24))h"
    }

    /// For VoiceOver: "2 hours 5 minutes", "1 day 14 hours", "45 minutes".
    public static func spoken(_ seconds: TimeInterval) -> String {
        let minutes = (wholeSecondsUp(seconds) + 59) / 60
        if minutes >= 1_440 {
            return joined(count(minutes / 1_440, "day"), count(minutes % 1_440 / 60, "hour"))
        }
        if minutes >= 60 {
            return joined(count(minutes / 60, "hour"), count(minutes % 60, "minute"))
        }
        return count(minutes, "minute")
    }

    private static func wholeSecondsUp(_ seconds: TimeInterval) -> Int {
        // The millisecond allowance absorbs floating-point noise on an exact boundary.
        max(0, Int((seconds - 0.001).rounded(.up)))
    }

    private static func count(_ value: Int, _ unit: String) -> String {
        value == 0 ? "" : "\(value) \(unit)\(value == 1 ? "" : "s")"
    }

    private static func joined(_ parts: String...) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
