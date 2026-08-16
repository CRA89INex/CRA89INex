import ActivityKit
import Foundation
import IntentionCore

/// Starts, updates, and ends the one Live Activity for the current session.
/// Live Activities are capped at ~8h active / ~12h on the Lock Screen
/// (§10); `refreshIfNeeded` is called whenever the app is foregrounded so a
/// long-running session's activity gets re-requested if iOS ended it.
@MainActor
final class LiveActivityController {
    private var activity: Activity<IntentionActivityAttributes>?

    func start(session: Session) {
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = IntentionActivityAttributes(sessionID: session.id)
        let state = IntentionActivityAttributes.ContentState(
            intentionText: session.intentionText,
            startedAt: session.startedAt,
            phase: .active
        )

        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(snapshot: SharedSessionSnapshot) {
        guard let activity else { return }
        let state = IntentionActivityAttributes.ContentState(snapshot: snapshot)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }

    /// Re-requests the activity if the session is still running but iOS
    /// ended the previous one after the 8h active-time cap.
    func refreshIfNeeded(session: Session?) {
        guard let session, session.isActive, activity == nil else { return }
        start(session: session)
    }
}
