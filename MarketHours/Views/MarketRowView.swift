import MarketHoursCore
import SwiftUI

struct MarketRowView: View {
    let schedule: MarketSchedule
    let status: MarketStatus
    let now: Date
    let viewer: TimeZone

    private var market: Market { schedule.market }
    private var closingSoon: Bool { status.isClosingSoon(at: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(market.flag)
                Text(market.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(schedule.localClockText(at: now))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                StatusPill(text: pillText, color: pillColor)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: status.next.startsTrading ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(status.next.startsTrading ? Color.green : Color.orange)
                Text(countdownText)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text(schedule.sessionRangeText(at: now, in: viewer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let progress = status.progress(at: now) {
                ProgressBar(progress: progress, tint: progressTint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .help(tooltip)
        .accessibilityElement(children: .combine)
    }

    /// "NYSE / Nasdaq: 09:30-16:00 New York time".
    private var tooltip: String {
        "\(market.exchange): \(market.regular) \(market.name) time"
    }

    private var countdownText: String {
        let remaining = DurationFormat.long(status.countdown(at: now))
        switch status.next.kind {
        case .open: return "Opens in \(remaining)"
        case .close: return "Closes in \(remaining)"
        case .lunchStart: return "Lunch in \(remaining)"
        case .lunchEnd: return "Resumes in \(remaining)"
        }
    }

    private var pillText: String {
        switch status.phase {
        case .open: return closingSoon ? "Closing soon" : "Open"
        case .lunch: return "Lunch"
        case .closed:
            if case .holiday = status.closedReason { return "Holiday" }
            return "Closed"
        }
    }

    private var pillColor: Color {
        switch status.phase {
        case .open: return closingSoon ? .orange : .green
        case .lunch: return .yellow
        case .closed:
            if case .holiday = status.closedReason { return .purple }
            return .secondary
        }
    }

    private var progressTint: Color {
        if closingSoon { return .orange }
        return status.phase == .lunch ? .secondary : .accentColor
    }

    private var note: String? {
        if case .holiday(let name) = status.closedReason { return name }
        if status.isSpecialSession { return "Shortened session today" }
        return nil
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

private struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(4, geo.size.width * progress))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
