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
        static let appearance = "settings.appearance"
        static let accentColor = "settings.accentColor"
    }

    /// The design's mint. Needed as an explicit fallback because `UserDefaults.integer` returns 0
    /// for a missing key, and 0 is black — an unset preference would otherwise read as a choice.
    ///
    /// Changing this moves every install that never picked an accent, which is the intent: the key
    /// stays unset until someone taps a swatch, so the default is the app's colour, not a value
    /// written once at first launch. An explicit choice is stored and survives.
    static let defaultAccentColorValue = 0x34D399

    private let defaults: UserDefaults

    /// Defaults to the group suite rather than `.standard`, so the share extension reads the same
    /// preferences the app writes.
    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.dailyReminderEnabled = defaults.bool(forKey: Key.dailyReminder)
        self.budgetAlertEnabled = defaults.bool(forKey: Key.budgetAlert)
        self.biometricLockEnabled = defaults.bool(forKey: Key.biometricLock)
        self.appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        let storedAccent = defaults.integer(forKey: Key.accentColor)
        self.accentColorValue = storedAccent == 0 ? Self.defaultAccentColorValue : storedAccent
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

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The accent as 0xRRGGBB. `Int` rather than `UInt32` because that is what `UserDefaults`
    /// stores natively.
    var accentColorValue: Int {
        didSet { defaults.set(accentColorValue, forKey: Key.accentColor) }
    }
}

/// Which palette the app draws with. `system` follows iOS rather than pinning an appearance, and is
/// the default so a fresh install matches the rest of the device.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}
