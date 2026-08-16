import Foundation

/// The two check-in cadences a person can choose when starting a session.
///
/// `vertiefung` protects flow with rare check-ins; `wachheit` checks in more
/// often for activities that are known to drift easily.
public enum SessionMode: String, Codable, CaseIterable, Sendable {
    case vertiefung
    case wachheit

    /// The band from which check-in intervals are sampled for this mode.
    public var baseIntervalRange: ClosedRange<TimeInterval> {
        switch self {
        case .wachheit:
            return 6 * 60 ... 12 * 60
        case .vertiefung:
            return 20 * 60 ... 40 * 60
        }
    }
}
