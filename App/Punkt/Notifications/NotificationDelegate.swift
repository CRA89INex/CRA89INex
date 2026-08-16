import UserNotifications
import IntentionCore

/// Routes the "Ja, dabei" / "Etwas anderes" / "Zurück" / "Noch etwas Zeit"
/// notification actions (§7) straight into the engine, so a check-in can be
/// answered without opening the app.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var sessionStore: SessionStore?

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            handle(response: response)
            completionHandler()
        }
    }

    /// Show the (silent, visual-only) banner even while the app is in the
    /// foreground — a check-in shouldn't depend on the app being backgrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }

    @MainActor
    private func handle(response: UNNotificationResponse) {
        guard let store = sessionStore else { return }

        switch response.actionIdentifier {
        case NotificationIdentifiers.checkInYesAction:
            store.answerCheckIn(.yes)
        case NotificationIdentifiers.checkInSomethingElseAction:
            store.answerCheckIn(.no)
        case NotificationIdentifiers.returnBackAction:
            store.confirmReturn()
        case NotificationIdentifiers.returnExtendAction:
            store.extendDetour(by: 5 * 60)
        case UNNotificationDefaultActionIdentifier:
            store.refreshAfterForeground()
        default:
            break
        }
    }
}
