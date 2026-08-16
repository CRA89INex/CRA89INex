import Foundation
import WidgetKit

/// Reads and writes the one piece of state the widget and Live Activity
/// need, in the App Group's `UserDefaults`. The app calls `save` whenever
/// `SessionEngine`'s phase or session changes; the widget's timeline
/// provider (and interactive `AppIntent`s) call `load`.
public struct SharedStateStore {
    private static let key = "currentSessionSnapshot"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func save(_ snapshot: SharedSessionSnapshot?) {
        guard let snapshot else {
            defaults.removeObject(forKey: Self.key)
            reloadWidgets()
            return
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.key)
        }
        reloadWidgets()
    }

    public func load() -> SharedSessionSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(SharedSessionSnapshot.self, from: data)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
