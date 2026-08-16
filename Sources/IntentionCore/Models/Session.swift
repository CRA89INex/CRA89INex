import Foundation
import SwiftData

/// The time under a single declared intention, from start to close.
///
/// `endedAt` is `nil` while the session is still running. `totalDuration`
/// deliberately includes any detour time — the main clock never pauses for
/// a detour (see `Detour`), because the gap between total time and
/// intentional time is the entire point of the app.
@Model
public final class Session {
    public var id: UUID
    public var intentionText: String
    public var startedAt: Date
    public var endedAt: Date?
    public var modeRawValue: String
    public var closingNote: String?
    /// True when the session was closed by the engine itself (e.g. after
    /// repeated unanswered check-ins), not by an explicit user action.
    public var endedAutomatically: Bool

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.session)
    public var checkIns: [CheckIn]

    @Relationship(deleteRule: .cascade, inverse: \Detour.session)
    public var detours: [Detour]

    public init(
        intentionText: String,
        startedAt: Date = .now,
        mode: SessionMode
    ) {
        self.id = UUID()
        self.intentionText = intentionText
        self.startedAt = startedAt
        self.endedAt = nil
        self.modeRawValue = mode.rawValue
        self.closingNote = nil
        self.endedAutomatically = false
        self.checkIns = []
        self.detours = []
    }

    public var mode: SessionMode {
        get { SessionMode(rawValue: modeRawValue) ?? .vertiefung }
        set { modeRawValue = newValue.rawValue }
    }

    /// Wall-clock time from start to close (or to `now` if still running).
    /// Includes detour time by design.
    public func totalDuration(asOf now: Date = .now) -> TimeInterval {
        (endedAt ?? now).timeIntervalSince(startedAt)
    }

    public var isActive: Bool { endedAt == nil }
}
