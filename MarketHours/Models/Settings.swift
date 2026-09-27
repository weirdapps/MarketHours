import Foundation
import Observation

/// User choices, persisted in UserDefaults.
@MainActor
@Observable
final class Settings {
    /// Markets hidden from the panel and from the menu bar's automatic pick.
    var hiddenMarketIDs: Set<String> {
        didSet { save(Array(hiddenMarketIDs).sorted(), Key.hidden) }
    }

    /// Markets that post a notification before they open and close.
    var alertMarketIDs: Set<String> {
        didSet { save(Array(alertMarketIDs).sorted(), Key.alerts) }
    }

    /// The market the menu bar always counts down to; nil picks the next event anywhere.
    var pinnedMarketID: String? {
        didSet { save(pinnedMarketID, Key.pinned) }
    }

    var menuBarShowsSeconds: Bool {
        didSet { save(menuBarShowsSeconds, Key.seconds) }
    }

    var alertLeadMinutes: Int {
        didSet { save(alertLeadMinutes, Key.lead) }
    }

    @ObservationIgnored var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hiddenMarketIDs = Set(defaults.stringArray(forKey: Key.hidden) ?? [])
        alertMarketIDs = Set(defaults.stringArray(forKey: Key.alerts) ?? [])
        pinnedMarketID = defaults.string(forKey: Key.pinned)
        menuBarShowsSeconds = defaults.bool(forKey: Key.seconds)
        let lead = defaults.integer(forKey: Key.lead)
        alertLeadMinutes = lead > 0 ? lead : 15
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }

    private enum Key {
        static let hidden = "hiddenMarkets"
        static let alerts = "alertMarkets"
        static let pinned = "pinnedMarket"
        static let seconds = "menuBarShowsSeconds"
        static let lead = "alertLeadMinutes"
    }
}
