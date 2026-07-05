//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import KeyValueStore

// MARK: - AppSettings

/// A container for application-wide user settings.
///
/// `AppSettings` provides observable properties that represent user preferences
/// and persists them using an underlying key–value store.
/// It is designed to be injected into SwiftUI views and other components
/// that depend on reactive settings.
///
@Observable @MainActor public final class AppSettings {

    // MARK: Key

    /// The keys used to store and retrieve settings from the underlying store.
    public enum Key: String {
        /// The preferred color scheme for the app.
        case colorScheme

        /// The app-wide display currency for totals and reports.
        case displayCurrencyCode

        /// Default reminder offsets (comma-separated days before) per kind.
        case reminderDefaultsMonthly
        case reminderDefaultsAnnual
        case reminderDefaultsTrial
        case reminderDefaultsManual

        // <-- (1 / 3) Add key for new property here
    }

    /// The reminder-default groups (spec Section 19).
    public enum ReminderDefaultKind {
        case monthly
        case annual
        case trial
        case manual
    }

    // MARK: Properties

    /// The app's current color scheme preference.
    public var colorScheme: AppColorScheme {
        didSet {
            store.save(colorScheme, for: .colorScheme)
        }
    }

    /// The app-wide display currency (spec Section 24). Default: SEK.
    public var displayCurrencyCode: String {
        didSet {
            store.save(displayCurrencyCode, for: .displayCurrencyCode)
        }
    }

    /// Default reminder offsets as comma-separated "days before" strings.
    public var reminderDefaultsMonthly: String {
        didSet { store.save(reminderDefaultsMonthly, for: .reminderDefaultsMonthly) }
    }

    public var reminderDefaultsAnnual: String {
        didSet { store.save(reminderDefaultsAnnual, for: .reminderDefaultsAnnual) }
    }

    public var reminderDefaultsTrial: String {
        didSet { store.save(reminderDefaultsTrial, for: .reminderDefaultsTrial) }
    }

    public var reminderDefaultsManual: String {
        didSet { store.save(reminderDefaultsManual, for: .reminderDefaultsManual) }
    }

    /// Parses the default reminder offsets for a kind into day counts.
    public func reminderOffsets(_ kind: ReminderDefaultKind) -> [Int] {
        let raw = switch kind {
        case .monthly: reminderDefaultsMonthly
        case .annual: reminderDefaultsAnnual
        case .trial: reminderDefaultsTrial
        case .manual: reminderDefaultsManual
        }
        return raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 0 }
    }

    // <-- (2 / 3) Add property for new property here

    // MARK: Setup

    /// The key–value store that backs this settings container.
    @ObservationIgnored
    private let store: AnyKeyValueStore<AppSettings.Key>

    /// Creates a new instance of `AppSettings`.
    ///
    /// - Parameter store: The store used to persist values. If `nil`,
    ///   defaults to a `UserDefaults`-backed store.
    ///
    public init(store: AnyKeyValueStore<AppSettings.Key>? = nil) {
        self.store = store ?? .defaultStore
        colorScheme = self.store.load(.colorScheme, default: .system)
        displayCurrencyCode = self.store.load(.displayCurrencyCode, default: "SEK")
        reminderDefaultsMonthly = self.store.load(.reminderDefaultsMonthly, default: "1")
        reminderDefaultsAnnual = self.store.load(.reminderDefaultsAnnual, default: "30, 7")
        reminderDefaultsTrial = self.store.load(.reminderDefaultsTrial, default: "3")
        reminderDefaultsManual = self.store.load(.reminderDefaultsManual, default: "30, 14")

        // <-- (3 / 3) Add initializer for new property here.
    }
}
