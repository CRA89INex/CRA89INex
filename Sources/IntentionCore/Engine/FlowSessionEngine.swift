import Foundation

/// UI-independent state machine for Flow mode: a fixed ramp-up period,
/// then an open-ended flow period ended manually, then an exit summary.
///
/// ```
/// IDLE --(startRamp)--> RAMP --(countdown expires, or skipToFlow)--> FLOW
///                                                                       |
///                                                                  (endFlow)
///                                                                       v
/// IDLE <--------------------------(reset)---------------------------- EXIT
/// ```
public final class FlowSessionEngine {
    public enum Phase: String, Equatable, Sendable {
        case idle
        case ramp
        case flow
        case exit
    }

    public private(set) var phase: Phase = .idle
    public private(set) var currentFlowSession: FlowSession?
    /// When the ramp countdown is due to expire, if currently ramping.
    public private(set) var rampEndsAt: Date?

    private let clock: SessionEngineClock
    private var flowStartedAt: Date?

    public var onPhaseChanged: ((Phase) -> Void)?
    public var onSessionChanged: ((FlowSession?) -> Void)?

    public init(clock: SessionEngineClock = SystemClock()) {
        self.clock = clock
    }

    @discardableResult
    public func startRamp(plannedRampDuration: TimeInterval) -> FlowSession {
        let session = FlowSession(startedAt: clock.now(), plannedRampDuration: plannedRampDuration)
        currentFlowSession = session
        rampEndsAt = clock.now().addingTimeInterval(plannedRampDuration)
        setPhase(.ramp)
        onSessionChanged?(session)
        return session
    }

    /// The ramp countdown ran out on its own.
    public func rampCountdownExpired() {
        guard phase == .ramp else { return }
        enterFlow(skipped: false)
    }

    /// The person tapped "Bin schon im Flow" before the countdown finished.
    public func skipToFlow() {
        guard phase == .ramp else { return }
        enterFlow(skipped: true)
    }

    public func endFlow() {
        guard phase == .flow, let session = currentFlowSession, let flowStartedAt else { return }
        session.flowDuration = clock.now().timeIntervalSince(flowStartedAt)
        session.endedAt = clock.now()
        setPhase(.exit)
        onSessionChanged?(session)
    }

    /// Leaves the exit summary and returns to idle, ready for a new session.
    public func reset() {
        guard phase == .exit else { return }
        currentFlowSession = nil
        flowStartedAt = nil
        rampEndsAt = nil
        setPhase(.idle)
        onSessionChanged?(nil)
    }

    private func enterFlow(skipped: Bool) {
        guard let session = currentFlowSession else { return }
        let now = clock.now()
        session.actualRampDuration = now.timeIntervalSince(session.startedAt)
        session.skippedRamp = skipped
        flowStartedAt = now
        rampEndsAt = nil
        setPhase(.flow)
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        onPhaseChanged?(newPhase)
    }
}
