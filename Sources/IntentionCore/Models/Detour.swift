import Foundation
import SwiftData

/// A deliberately time-boxed interruption ("Ich mach kurz die Tür auf —
/// 2 Minuten"). The session's main clock keeps running while a detour is
/// open; `actualDuration` compared against `totalPlannedDuration` is what
/// makes the detour-overrun number in the Muster screen meaningful.
@Model
public final class Detour {
    public var id: UUID
    public var reason: String
    public var plannedDuration: TimeInterval
    public var startedAt: Date
    public var endedAt: Date?
    public var extensions: [TimeInterval]
    /// True only if the person came back to the original intention.
    /// False if they instead started a new intention from the return prompt.
    public var returned: Bool
    public var session: Session?

    public init(
        reason: String,
        plannedDuration: TimeInterval,
        startedAt: Date = .now
    ) {
        self.id = UUID()
        self.reason = reason
        self.plannedDuration = plannedDuration
        self.startedAt = startedAt
        self.endedAt = nil
        self.extensions = []
        self.returned = false
    }

    public var totalPlannedDuration: TimeInterval {
        plannedDuration + extensions.reduce(0, +)
    }

    public var actualDuration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    public var isOpen: Bool { endedAt == nil }

    /// The moment the countdown (including any extensions) is due to expire.
    public var currentCountdownEnd: Date {
        startedAt.addingTimeInterval(totalPlannedDuration)
    }
}
