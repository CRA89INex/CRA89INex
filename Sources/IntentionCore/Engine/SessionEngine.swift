import Foundation

/// The UI-independent core of the app: a state machine over one active
/// `Session`, driving check-in scheduling and detour/return handling.
///
/// `SessionEngine` never touches SwiftUI, notifications, or haptics
/// directly. Callers observe the `on...` callbacks (or read the published
/// state after each call) and are responsible for side effects like
/// scheduling a `UNNotificationRequest` or updating a Live Activity.
public final class SessionEngine {
    public enum Phase: String, Equatable, Sendable {
        case idle
        case active
        case checkIn
        case correction
        case detour
        case returnPrompt
    }

    /// Fokus's fixed check-in schedule: offsets from session start.
    /// The "5 min before end" notice at the 90-minute mark is deliberately
    /// not here — it's informational, not a check-in, and is scheduled by
    /// the app layer instead (see `SessionStore`).
    public static let fokusCheckInOffsets: [TimeInterval] = [25 * 60, 40 * 60]

    // MARK: State

    public private(set) var phase: Phase = .idle
    public private(set) var currentSession: Session?
    public private(set) var currentDetour: Detour?
    public private(set) var pendingCheckIn: CheckIn?
    public private(set) var missedCheckInStreak: Int = 0
    public private(set) var nextCheckInDue: Date?

    // MARK: Configuration

    private let clock: SessionEngineClock
    public let gracePeriod: TimeInterval
    public let maxMissedCheckIns: Int
    private var intervalSample: (ClosedRange<TimeInterval>) -> TimeInterval
    /// Anker-only; `nil` for Fokus sessions, which use `fokusCheckInOffsets` instead.
    private var intervalPolicy: CheckInIntervalPolicy?
    /// Remembers the last chosen Anker pace so `chooseNewIntention` can
    /// carry it forward when it isn't respecified.
    private var lastAnkerIntervalMinutes: TimeInterval = 6

    // MARK: Side-effect hooks (set by the app layer)

    public var onPhaseChanged: ((Phase) -> Void)?
    public var onSessionChanged: ((Session?) -> Void)?
    public var onDetourChanged: ((Detour?) -> Void)?
    public var onScheduleCheckIn: ((Date) -> Void)?
    public var onSessionEnded: ((Session) -> Void)?

    public init(
        clock: SessionEngineClock = SystemClock(),
        gracePeriod: TimeInterval = 10 * 60,
        maxMissedCheckIns: Int = 3,
        intervalSample: @escaping (ClosedRange<TimeInterval>) -> TimeInterval = { .random(in: $0) }
    ) {
        self.clock = clock
        self.gracePeriod = gracePeriod
        self.maxMissedCheckIns = maxMissedCheckIns
        self.intervalSample = intervalSample
    }

    // MARK: Starting

    /// `ankerIntervalMinutes` (3–12) only matters for `.anker`; ignored for `.fokus`.
    @discardableResult
    public func startSession(intentionText: String, mode: SessionMode, ankerIntervalMinutes: TimeInterval? = nil) -> Session {
        let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = Session(intentionText: trimmed, startedAt: clock.now(), mode: mode)
        currentSession = session

        switch mode {
        case .anker:
            let minutes = ankerIntervalMinutes ?? lastAnkerIntervalMinutes
            lastAnkerIntervalMinutes = minutes
            intervalPolicy = CheckInIntervalPolicy(baseRange: CheckInIntervalPolicy.aroundChosenPace(minutes))
        case .fokus:
            intervalPolicy = nil
        }

        missedCheckInStreak = 0
        setPhase(.active)
        scheduleNextCheckIn()
        onSessionChanged?(session)
        return session
    }

    // MARK: Check-ins

    /// Call when a scheduled check-in's time has arrived (e.g. the app is
    /// foregrounded, or a background task observes `nextCheckInDue` has passed).
    public func checkInDue() {
        guard phase == .active, let session = currentSession else { return }
        let checkIn = CheckIn(at: clock.now())
        session.checkIns.append(checkIn)
        pendingCheckIn = checkIn
        setPhase(.checkIn)
    }

    public func answerCheckIn(_ response: CheckInResponse, actualActivityText: String? = nil) {
        guard phase == .checkIn, pendingCheckIn != nil else { return }
        guard response != .unanswered else {
            expirePendingCheckIn()
            return
        }

        let pending = pendingCheckIn!
        pending.response = response
        pending.actualActivityText = actualActivityText
        pendingCheckIn = nil
        missedCheckInStreak = 0
        intervalPolicy?.recordAnswer(response)

        switch response {
        case .yes:
            setPhase(.active)
            scheduleNextCheckIn()
        case .no:
            setPhase(.correction)
        case .unanswered:
            break // unreachable, handled above
        }
    }

    /// Call when a check-in notification's response window elapses without
    /// an answer. Logged as "unanswered", never as a failure.
    public func expirePendingCheckIn() {
        guard phase == .checkIn, let pending = pendingCheckIn else { return }
        pending.response = .unanswered
        pendingCheckIn = nil
        missedCheckInStreak += 1
        intervalPolicy?.recordAnswer(.unanswered)

        if missedCheckInStreak >= maxMissedCheckIns {
            sleepSession()
        } else {
            setPhase(.active)
            scheduleNextCheckIn()
        }
    }

    // MARK: Correction

    /// The person tapped the dot themselves, outside of a check-in.
    public func requestCorrection() {
        guard phase == .active else { return }
        setPhase(.correction)
    }

    public func chooseDetour(reason: String, plannedDuration: TimeInterval) {
        guard phase == .correction, let session = currentSession else { return }
        let detour = Detour(reason: reason, plannedDuration: plannedDuration, startedAt: clock.now())
        session.detours.append(detour)
        currentDetour = detour
        onDetourChanged?(detour)
        setPhase(.detour)
    }

    public func chooseNewIntention(_ text: String, mode: SessionMode? = nil, ankerIntervalMinutes: TimeInterval? = nil) {
        guard phase == .correction || phase == .returnPrompt else { return }
        let priorMode = mode ?? currentSession?.mode ?? .fokus
        if phase == .returnPrompt, let detour = currentDetour {
            detour.endedAt = clock.now()
            detour.returned = false
        }
        _ = closeCurrentSession(automatically: false)
        startSession(intentionText: text, mode: priorMode, ankerIntervalMinutes: ankerIntervalMinutes)
    }

    @discardableResult
    public func endSession(closingNote: String? = nil) -> Session? {
        guard phase == .active || phase == .correction else { return nil }
        return closeCurrentSession(automatically: false, closingNote: closingNote)
    }

    // MARK: Detour / return

    /// The detour's countdown (including any extensions) has run out.
    public func detourCountdownExpired() {
        guard phase == .detour else { return }
        setPhase(.returnPrompt)
    }

    /// Returns to the original intention. Valid both as an early return
    /// (still in `.detour`) and after the return prompt fires.
    public func confirmReturn() {
        guard phase == .detour || phase == .returnPrompt, let detour = currentDetour else { return }
        detour.endedAt = clock.now()
        detour.returned = true
        currentDetour = nil
        onDetourChanged?(nil)
        setPhase(.active)
    }

    public func extendDetour(by additionalDuration: TimeInterval) {
        guard phase == .returnPrompt, let detour = currentDetour else { return }
        detour.extensions.append(additionalDuration)
        intervalPolicy?.recordMissedDetourReturn()
        onDetourChanged?(detour)
        setPhase(.detour)
    }

    // MARK: Internals

    private func scheduleNextCheckIn() {
        guard let session = currentSession else { return }

        switch session.mode {
        case .anker:
            scheduleNextAdaptiveCheckIn(for: session)
        case .fokus:
            scheduleNextFixedCheckIn(for: session)
        }
    }

    private func scheduleNextAdaptiveCheckIn(for session: Session) {
        guard let policy = intervalPolicy else { return }
        let sampled = policy.nextInterval(sample: intervalSample)

        let due: Date
        if session.checkIns.isEmpty {
            let elapsedSinceStart = clock.now().timeIntervalSince(session.startedAt)
            let remainingGrace = max(0, gracePeriod - elapsedSinceStart)
            due = clock.now().addingTimeInterval(max(sampled, remainingGrace))
        } else {
            due = clock.now().addingTimeInterval(sampled)
        }
        nextCheckInDue = due
        onScheduleCheckIn?(due)
    }

    /// Fokus has exactly two fixed check-ins (25min, 40min from start); after
    /// that, no more get scheduled. The count of check-ins already logged
    /// for this session (`session.checkIns.count`) is the source of truth
    /// for which one comes next, so this stays correct across correction/
    /// detour detours that don't themselves add a `CheckIn`.
    private func scheduleNextFixedCheckIn(for session: Session) {
        let index = session.checkIns.count
        guard index < Self.fokusCheckInOffsets.count else {
            nextCheckInDue = nil
            return
        }
        let due = session.startedAt.addingTimeInterval(Self.fokusCheckInOffsets[index])
        nextCheckInDue = due
        onScheduleCheckIn?(due)
    }

    private func sleepSession() {
        _ = closeCurrentSession(automatically: true, closingNote: nil)
    }

    @discardableResult
    private func closeCurrentSession(automatically: Bool, closingNote: String? = nil) -> Session? {
        guard let session = currentSession else { return nil }
        session.endedAt = clock.now()
        session.endedAutomatically = automatically
        if let closingNote {
            session.closingNote = closingNote
        }

        currentSession = nil
        currentDetour = nil
        pendingCheckIn = nil
        intervalPolicy = nil
        nextCheckInDue = nil
        missedCheckInStreak = 0

        setPhase(.idle)
        onDetourChanged?(nil)
        onSessionChanged?(nil)
        onSessionEnded?(session)
        return session
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        onPhaseChanged?(newPhase)
    }
}
