import Foundation
import Observation
import SwiftData
import IntentionCore

/// Bridges `FlowSessionEngine` to SwiftUI: forwards user actions into the
/// engine, persists `FlowSession` via SwiftData, and runs the ramp
/// countdown while the app is foregrounded. Unlike `SessionStore`, Flow
/// mode has no check-ins and no background notifications to schedule —
/// the whole thing only needs a foreground timer for the ramp countdown.
@Observable
@MainActor
final class FlowSessionStore {
    private(set) var phase: FlowSessionEngine.Phase = .idle
    private(set) var flowSession: FlowSession?
    private(set) var rampEndsAt: Date?

    private let engine: FlowSessionEngine
    private let modelContext: ModelContext
    private var rampWaitTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.engine = FlowSessionEngine()
        wireEngine()
    }

    func startRamp(duration: TimeInterval) {
        guard phase == .idle else { return }
        engine.startRamp(plannedRampDuration: duration)
    }

    func skipToFlow() {
        engine.skipToFlow()
        Haptics.confirmation()
    }

    func endFlow() {
        engine.endFlow()
        Haptics.confirmation()
    }

    func reset() {
        engine.reset()
    }

    /// Call when the app becomes active, in case the ramp countdown
    /// finished while backgrounded.
    func refreshAfterForeground() {
        if phase == .ramp, let rampEndsAt, rampEndsAt <= .now {
            engine.rampCountdownExpired()
        }
    }

    private func wireEngine() {
        engine.onPhaseChanged = { [weak self] phase in
            self?.handlePhaseChanged(phase)
        }
        engine.onSessionChanged = { [weak self] session in
            self?.handleSessionChanged(session)
        }
    }

    private func handlePhaseChanged(_ phase: FlowSessionEngine.Phase) {
        self.phase = phase
        rampEndsAt = engine.rampEndsAt
        rampWaitTask?.cancel()

        if phase == .ramp, let rampEndsAt {
            rampWaitTask = Task { [weak self] in
                let delay = rampEndsAt.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                self?.engine.rampCountdownExpired()
            }
        }
    }

    private func handleSessionChanged(_ session: FlowSession?) {
        flowSession = session
        if let session, session.modelContext == nil {
            modelContext.insert(session)
        }
        try? modelContext.save()
    }
}
