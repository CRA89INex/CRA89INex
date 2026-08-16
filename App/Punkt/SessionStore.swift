import Foundation
import Observation
import SwiftData
import IntentionCore

/// Bridges the UI-independent `SessionEngine` to SwiftUI: it forwards user
/// actions into the engine, persists the resulting `Session`/`CheckIn`/
/// `Detour` objects via SwiftData, keeps the App Group snapshot and the
/// Live Activity in sync, and schedules the local notifications that make
/// check-ins and return prompts work while the app isn't in the foreground.
@Observable
@MainActor
final class SessionStore {
    private(set) var phase: SessionEngine.Phase = .idle
    private(set) var session: Session?
    private(set) var detour: Detour?
    private(set) var pendingCheckIn: CheckIn?
    private(set) var recentIntentions: [String] = []

    private let engine: SessionEngine
    private let modelContext: ModelContext
    private let notificationScheduler: NotificationScheduler
    private let sharedStateStore: SharedStateStore
    private let liveActivityController = LiveActivityController()

    private var checkInWaitTask: Task<Void, Never>?
    private var pendingCheckInTimeoutTask: Task<Void, Never>?

    /// How long a delivered check-in stays open before it's logged as
    /// "unanswered" (§7). Kept short: the point is a glance, not a task.
    private let checkInResponseWindow: TimeInterval = 5 * 60

    init(
        modelContext: ModelContext,
        notificationScheduler: NotificationScheduler = NotificationScheduler(),
        sharedStateStore: SharedStateStore = SharedStateStore()
    ) {
        self.modelContext = modelContext
        self.notificationScheduler = notificationScheduler
        self.sharedStateStore = sharedStateStore
        self.engine = SessionEngine()
        wireEngine()
        loadRecentIntentions()
    }

    // MARK: User-facing actions

    func startSession(intentionText: String, mode: SessionMode) {
        guard !intentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        engine.startSession(intentionText: intentionText, mode: mode)
        rememberIntention(intentionText)
    }

    func answerCheckIn(_ response: CheckInResponse, actualActivityText: String? = nil) {
        engine.answerCheckIn(response, actualActivityText: actualActivityText)
    }

    func requestCorrection() {
        engine.requestCorrection()
    }

    func chooseDetour(reason: String, plannedDuration: TimeInterval) {
        engine.chooseDetour(reason: reason, plannedDuration: plannedDuration)
    }

    func chooseNewIntention(_ text: String) {
        engine.chooseNewIntention(text)
        rememberIntention(text)
    }

    func endSession(closingNote: String? = nil) {
        engine.endSession(closingNote: closingNote)
    }

    func confirmReturn() {
        engine.confirmReturn()
    }

    func extendDetour(by additionalDuration: TimeInterval) {
        engine.extendDetour(by: additionalDuration)
    }

    /// Call when the app becomes active, in case a scheduled moment (a
    /// check-in or a detour countdown) passed while it was in the background.
    func refreshAfterForeground() {
        if let pending = PendingActionStore().consume() {
            apply(pending)
        }
        if phase == .active, let due = engine.nextCheckInDue, due <= .now {
            fireCheckInIfDue()
        }
        if phase == .detour, let detour, detour.currentCountdownEnd <= .now {
            engine.detourCountdownExpired()
        }
        liveActivityController.refreshIfNeeded(session: session)
    }

    private func apply(_ action: PendingActivityAction) {
        switch action {
        case .checkInYes: engine.answerCheckIn(.yes)
        case .checkInNo: engine.answerCheckIn(.no)
        case .returnBack: engine.confirmReturn()
        case .returnExtend: engine.extendDetour(by: 5 * 60)
        }
    }

    // MARK: Engine wiring

    private func wireEngine() {
        engine.onPhaseChanged = { [weak self] phase in
            self?.handlePhaseChanged(phase)
        }
        engine.onSessionChanged = { [weak self] session in
            self?.handleSessionChanged(session)
        }
        engine.onDetourChanged = { [weak self] detour in
            self?.detour = detour
            self?.publishSnapshot()
        }
        engine.onScheduleCheckIn = { [weak self] date in
            self?.handleScheduledCheckIn(date)
        }
        engine.onSessionEnded = { [weak self] session in
            self?.handleSessionEnded(session)
        }
    }

    private func handlePhaseChanged(_ phase: SessionEngine.Phase) {
        self.phase = phase
        pendingCheckIn = engine.pendingCheckIn

        if phase != .checkIn {
            pendingCheckInTimeoutTask?.cancel()
            notificationScheduler.cancelAllPending()
        }
        if phase == .detour, let detour {
            Task {
                await notificationScheduler.scheduleReturnPrompt(
                    originalIntentionText: session?.intentionText ?? "",
                    fireDate: detour.currentCountdownEnd
                )
            }
        }
        if phase == .idle {
            checkInWaitTask?.cancel()
            liveActivityController.end()
        }
        publishSnapshot()
    }

    private func handleSessionChanged(_ session: Session?) {
        self.session = session
        if let session, session.modelContext == nil {
            modelContext.insert(session)
            liveActivityController.start(session: session)
        }
        try? modelContext.save()
        publishSnapshot()
    }

    private func handleSessionEnded(_ session: Session) {
        try? modelContext.save()
        liveActivityController.end()
        sharedStateStore.save(nil)
    }

    private func handleScheduledCheckIn(_ date: Date) {
        checkInWaitTask?.cancel()
        let intentionText = session?.intentionText ?? ""

        Task {
            await notificationScheduler.scheduleCheckIn(intentionText: intentionText, fireDate: date)
        }

        checkInWaitTask = Task { [weak self] in
            let delay = date.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.fireCheckInIfDue()
        }
    }

    private func fireCheckInIfDue() {
        guard phase == .active else { return }
        engine.checkInDue()
        Haptics.checkIn()
        startPendingCheckInTimeout()
    }

    private func startPendingCheckInTimeout() {
        pendingCheckInTimeoutTask?.cancel()
        pendingCheckInTimeoutTask = Task { [weak self] in
            guard let window = self?.checkInResponseWindow else { return }
            try? await Task.sleep(for: .seconds(window))
            guard !Task.isCancelled, let self, self.phase == .checkIn else { return }
            self.engine.expirePendingCheckIn()
        }
    }

    private func publishSnapshot() {
        guard let session, phase != .idle,
              let snapshotPhase = SessionPhaseSnapshot(rawValue: phase.rawValue) else {
            sharedStateStore.save(nil)
            return
        }
        let snapshot = SharedSessionSnapshot(
            intentionText: session.intentionText,
            startedAt: session.startedAt,
            mode: session.mode,
            phase: snapshotPhase,
            detourReason: detour?.reason,
            detourCountdownEnd: detour?.currentCountdownEnd
        )
        sharedStateStore.save(snapshot)
        liveActivityController.update(snapshot: snapshot)
    }

    // MARK: Recent intentions (§9 — up to 5 tappable suggestions)

    private static let recentIntentionsKey = "recentIntentions"

    private func loadRecentIntentions() {
        recentIntentions = (AppGroup.defaults.array(forKey: Self.recentIntentionsKey) as? [String]) ?? []
    }

    private func rememberIntention(_ text: String) {
        var updated = recentIntentions.filter { $0 != text }
        updated.insert(text, at: 0)
        recentIntentions = Array(updated.prefix(5))
        AppGroup.defaults.set(recentIntentions, forKey: Self.recentIntentionsKey)
    }
}
