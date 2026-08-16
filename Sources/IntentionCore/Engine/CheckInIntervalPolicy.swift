import Foundation

/// Computes when the next check-in should fire.
///
/// Intervals are sampled uniformly from the mode's band so they can't be
/// anticipated. Two consecutive "yes" answers damp the cadence (flow is
/// left alone); a "no" or a missed detour return compresses it again.
public struct CheckInIntervalPolicy: Sendable {
    public let mode: SessionMode

    /// Multiplies the sampled interval. > 1 lengthens it (flow protection),
    /// < 1 shortens it (drift detected). Clamped to stay well-behaved.
    public private(set) var driftFactor: Double

    private var consecutiveYes: Int

    private static let minDriftFactor = 0.4
    private static let maxDriftFactor = 3.0
    private static let dampingStep = 1.5
    private static let compressionStep = 0.6

    public init(mode: SessionMode) {
        self.mode = mode
        self.driftFactor = 1.0
        self.consecutiveYes = 0
    }

    /// Feed the outcome of a resolved check-in into the policy.
    public mutating func recordAnswer(_ response: CheckInResponse) {
        switch response {
        case .yes:
            consecutiveYes += 1
            if consecutiveYes >= 2 {
                driftFactor = min(driftFactor * Self.dampingStep, Self.maxDriftFactor)
            }
        case .no:
            consecutiveYes = 0
            driftFactor = max(driftFactor * Self.compressionStep, Self.minDriftFactor)
        case .unanswered:
            consecutiveYes = 0
        }
    }

    /// A detour whose countdown expired without the person returning also
    /// counts as drift, independent of check-in answers.
    public mutating func recordMissedDetourReturn() {
        consecutiveYes = 0
        driftFactor = max(driftFactor * Self.compressionStep, Self.minDriftFactor)
    }

    /// Samples the next raw interval (before any grace-period flooring).
    ///
    /// `sample` defaults to a uniform draw from the system RNG; tests inject
    /// a deterministic sampler to make the outcome reproducible.
    public func nextInterval(
        sample: (ClosedRange<TimeInterval>) -> TimeInterval = { .random(in: $0) }
    ) -> TimeInterval {
        sample(mode.baseIntervalRange) * driftFactor
    }
}
