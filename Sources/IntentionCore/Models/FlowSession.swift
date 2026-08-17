import Foundation
import SwiftData

/// A Flow-mode session: a fixed ramp-up period followed by an open-ended
/// flow period, ended manually. Unlike `Session`, there's no intention
/// text, no check-ins, and no detours — it's a different, simpler shape
/// for people who want a warm-up-then-flow timer rather than an
/// intention/drift check-in loop.
@Model
public final class FlowSession {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var plannedRampDuration: TimeInterval
    /// How long the ramp actually ran — equal to `plannedRampDuration`
    /// unless `skippedRamp` is true, in which case it's shorter.
    public var actualRampDuration: TimeInterval?
    /// True if the person tapped "Bin schon im Flow" during the ramp
    /// instead of letting the countdown finish.
    public var skippedRamp: Bool
    public var flowDuration: TimeInterval?

    public init(startedAt: Date = .now, plannedRampDuration: TimeInterval) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = nil
        self.plannedRampDuration = plannedRampDuration
        self.actualRampDuration = nil
        self.skippedRamp = false
        self.flowDuration = nil
    }

    public var isActive: Bool { endedAt == nil }
}
