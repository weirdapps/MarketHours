import MarketHoursCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Bindable var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("Markets") {
                ForEach(Market.all) { market in
                    HStack {
                        Toggle(isOn: shown(market)) {
                            Text("\(market.flag) \(market.name)")
                        }
                        .toggleStyle(.checkbox)
                        Text(market.exchange)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Toggle(isOn: alerted(market)) {
                            Image(systemName: settings.alertMarketIDs.contains(market.id) ? "bell.fill" : "bell")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.plain)
                        .foregroundStyle(settings.alertMarketIDs.contains(market.id) ? Color.accentColor : .secondary)
                        .help("Notify before \(market.name) opens and closes")
                        .accessibilityLabel("Alerts for \(market.name)")
                    }
                }
            }

            section("Menu bar") {
                Picker("Count down to", selection: $settings.pinnedMarketID) {
                    Text("Next event, any market").tag(String?.none)
                    Divider()
                    ForEach(Market.all) { market in
                        Text("\(market.flag) \(market.name)").tag(Optional(market.id))
                    }
                }
                Toggle("Show seconds", isOn: $settings.menuBarShowsSeconds)
            }

            section("Alerts") {
                Picker("Notify", selection: $settings.alertLeadMinutes) {
                    ForEach([5, 10, 15, 30], id: \.self) { minutes in
                        Text("\(minutes) min before").tag(minutes)
                    }
                }
                Text("Turn alerts on per market with the bell above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.alerts.authorization == .denied {
                    HStack {
                        Text("Notifications are off for Market Hours.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Open Settings") { model.alerts.openNotificationSettings() }
                            .controlSize(.small)
                    }
                }
            }

            section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin.isEnabled },
                    set: { model.launchAtLogin.setEnabled($0) }
                ))
                if model.launchAtLogin.status == .requiresApproval {
                    HStack {
                        Text("Approve Market Hours in Login Items.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Open Login Items") { model.launchAtLogin.openLoginItemsSettings() }
                            .controlSize(.small)
                    }
                }
                if let error = model.launchAtLogin.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            section("Data") {
                Text(model.holidayDataDescription)
                    .font(.caption)
                    .foregroundStyle(model.holidayDataEndsSoon ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .onAppear {
            model.launchAtLogin.refresh()
            Task { await model.alerts.refreshAuthorization() }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func shown(_ market: Market) -> Binding<Bool> {
        Binding(
            get: { !settings.hiddenMarketIDs.contains(market.id) },
            set: { isShown in
                if isShown {
                    settings.hiddenMarketIDs.remove(market.id)
                } else {
                    settings.hiddenMarketIDs.insert(market.id)
                }
            }
        )
    }

    private func alerted(_ market: Market) -> Binding<Bool> {
        Binding(
            get: { settings.alertMarketIDs.contains(market.id) },
            set: { isOn in
                if isOn {
                    settings.alertMarketIDs.insert(market.id)
                } else {
                    settings.alertMarketIDs.remove(market.id)
                }
            }
        )
    }
}
