import Foundation

/// The two check-in-based ways to run an intention session. (Flow mode is
/// deliberately not a case here — it has no check-ins at all and lives
/// entirely in `FlowSessionEngine`.)
///
/// - `fokus`: a bounded, structured work block with a fixed check-in
///   schedule (see `SessionEngine.fokusCheckInOffsets`).
/// - `anker`: frequent, gentle check-ins at a pace the person chooses
///   (see `CheckInIntervalPolicy`).
public enum SessionMode: String, Codable, CaseIterable, Sendable {
    case fokus
    case anker
}
