import Foundation
@testable import IntentionCore

final class TestClock: SessionEngineClock {
    private(set) var current: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.current = date
    }

    func now() -> Date { current }

    func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }
}
