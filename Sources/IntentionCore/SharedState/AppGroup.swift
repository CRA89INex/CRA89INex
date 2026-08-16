import Foundation

/// The App Group shared between the app, the widget extension, and the
/// Live Activity. Replace `identifier` with your own Team's group id and
/// keep it in sync with the `com.apple.security.application-groups`
/// entitlement on every target (see README).
public enum AppGroup {
    public static let identifier = "group.de.cyberriskadvisor.punkt"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Where the SwiftData store lives so the app and the widget extension
    /// (for read-only history access, if ever needed) see the same data.
    public static var modelStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("IntentionTracker.sqlite")
    }
}
