import Foundation

/// Addresses the app links out to, read from Info.plist rather than written into a view.
///
/// Keeping them in the bundle means the destination can change per build — a fork, a staging page,
/// a different host — without touching Swift, and a malformed or missing value returns nil instead
/// of trapping the way a force-unwrapped `URL(string:)!` would.
enum AppLinks {
    static var privacyPolicy: URL? { url(forInfoKey: "PrivacyPolicyURL") }

    private static func url(forInfoKey key: String) -> URL? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !string.isEmpty else {
            return nil
        }
        return URL(string: string)
    }
}
