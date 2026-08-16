import ActivityKit
import Foundation

/// The Live Activity shown on the Lock Screen and in the Dynamic Island.
/// `sessionID` is fixed for the activity's lifetime; everything that
/// changes over time lives in `ContentState`.
public struct IntentionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var intentionText: String
        public var startedAt: Date
        public var phase: SessionPhaseSnapshot
        public var detourReason: String?
        public var detourCountdownEnd: Date?

        public init(
            intentionText: String,
            startedAt: Date,
            phase: SessionPhaseSnapshot,
            detourReason: String? = nil,
            detourCountdownEnd: Date? = nil
        ) {
            self.intentionText = intentionText
            self.startedAt = startedAt
            self.phase = phase
            self.detourReason = detourReason
            self.detourCountdownEnd = detourCountdownEnd
        }

        public init(snapshot: SharedSessionSnapshot) {
            self.init(
                intentionText: snapshot.intentionText,
                startedAt: snapshot.startedAt,
                phase: snapshot.phase,
                detourReason: snapshot.detourReason,
                detourCountdownEnd: snapshot.detourCountdownEnd
            )
        }
    }

    public var sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
