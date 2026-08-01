import Foundation

/// The container the app and the share extension both write to.
///
/// An extension runs as its own process in its own sandbox, so without a shared group each would
/// keep a private ledger and neither would ever see the other's transactions.
enum AppGroup {
    static let identifier = "group.com.davidjeong.ledger"

    /// nil when the App Groups entitlement is missing or names a group that is not provisioned.
    /// That is a build configuration problem rather than something to recover from at runtime, so
    /// callers surface it instead of quietly falling back to a private location.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL? {
        containerURL?.appending(path: "Ledger.store")
    }

    /// Preferences live in the group too, so the extension draws in the appearance and accent the
    /// user picked in the app rather than reverting to the defaults.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
