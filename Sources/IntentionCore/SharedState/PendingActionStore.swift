import Foundation

/// Interactive buttons on a Live Activity / Home Screen widget run as
/// `AppIntent`s inside the widget extension's own process, not the app's —
/// they cannot call into the running `SessionEngine` directly. With no
/// server and no push channel (§10), the honest solution is: the intent
/// records what was requested here, and the app applies it the next time
/// it's foregrounded (`SessionStore.refreshAfterForeground`).
public enum PendingActivityAction: String, Codable, Sendable {
    case checkInYes
    case checkInNo
    case returnBack
    case returnExtend
}

public struct PendingActionStore {
    private static let key = "pendingActivityAction"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func write(_ action: PendingActivityAction) {
        defaults.set(action.rawValue, forKey: Self.key)
    }

    /// Reads and clears the pending action, if any.
    public func consume() -> PendingActivityAction? {
        guard let raw = defaults.string(forKey: Self.key) else { return nil }
        defaults.removeObject(forKey: Self.key)
        return PendingActivityAction(rawValue: raw)
    }
}
