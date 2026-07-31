import Foundation
import Observation

/// User preferences for the settings screen, persisted in UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let dailyReminder = "settings.dailyReminder"
        static let budgetAlert = "settings.budgetAlert"
        static let biometricLock = "settings.biometricLock"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.dailyReminderEnabled = defaults.bool(forKey: Key.dailyReminder)
        self.budgetAlertEnabled = defaults.bool(forKey: Key.budgetAlert)
        self.biometricLockEnabled = defaults.bool(forKey: Key.biometricLock)
    }

    var dailyReminderEnabled: Bool {
        didSet { defaults.set(dailyReminderEnabled, forKey: Key.dailyReminder) }
    }

    var budgetAlertEnabled: Bool {
        didSet { defaults.set(budgetAlertEnabled, forKey: Key.budgetAlert) }
    }

    var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: Key.biometricLock) }
    }
}
