import Foundation

/// A lightweight, `Codable` mirror of the engine's phase — deliberately
/// without associated values so it can round-trip through `UserDefaults`
/// (App Group) and into the widget's `TimelineEntry` / the Live Activity's
/// `ContentState` without pulling in SwiftData.
public enum SessionPhaseSnapshot: String, Codable, Sendable {
    case idle
    case active
    case checkIn
    case correction
    case detour
    case returnPrompt
}

/// Everything the widget and Live Activity need to render, without touching
/// the SwiftData store. Written by the app (or the widget's own App
/// Intents, when they act directly) every time `SessionEngine`'s state
/// changes.
public struct SharedSessionSnapshot: Codable, Equatable, Sendable {
    public var intentionText: String
    public var startedAt: Date
    public var mode: SessionMode
    public var phase: SessionPhaseSnapshot

    public var detourReason: String?
    public var detourCountdownEnd: Date?

    public init(
        intentionText: String,
        startedAt: Date,
        mode: SessionMode,
        phase: SessionPhaseSnapshot,
        detourReason: String? = nil,
        detourCountdownEnd: Date? = nil
    ) {
        self.intentionText = intentionText
        self.startedAt = startedAt
        self.mode = mode
        self.phase = phase
        self.detourReason = detourReason
        self.detourCountdownEnd = detourCountdownEnd
    }
}
