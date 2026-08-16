import Foundation

/// Abstracts "now" so `SessionEngine` can be driven deterministically in tests.
public protocol SessionEngineClock {
    func now() -> Date
}

public struct SystemClock: SessionEngineClock {
    public init() {}
    public func now() -> Date { Date() }
}
