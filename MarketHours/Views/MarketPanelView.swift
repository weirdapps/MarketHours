import AppKit
import SwiftUI

struct MarketPanelView: View {
    @EnvironmentObject private var clock: MarketClock

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(clock.snapshots) { snapshot in
                        MarketRowView(
                            snapshot: snapshot,
                            localTime: clock.formattedLocalTime(for: snapshot.market)
                        )
                    }
                }
                .padding(14)
            }
            Divider().opacity(0.35)
            footer
        }
        .frame(width: 340, height: 520)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.85), Color.cyan.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Market Hours")
                    .font(.headline)
                Text("Major equity sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Text("Weekends closed · local sessions")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct MarketRowView: View {
    let snapshot: MarketSnapshot
    let localTime: String

    private var isOpen: Bool { snapshot.status == .open }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.market.flag)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.market.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(localTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            HStack {
                Image(systemName: isOpen ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    .foregroundStyle(isOpen ? Color.orange : Color.green)
                Text(snapshot.countdownLabel)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .monospacedDigit()
                Spacer()
            }

            if let progress = snapshot.sessionProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.cyan.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var statusBadge: some View {
        Text(isOpen ? "Open" : "Closed")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isOpen ? Color.green : Color.secondary)
            .background(
                Capsule()
                    .fill(isOpen ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
            )
    }
}
