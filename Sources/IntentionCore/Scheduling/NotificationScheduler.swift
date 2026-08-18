import Foundation
import UserNotifications

/// Identifiers for the notification category and its actions, shared
/// between where notifications are scheduled (the app) and where their
/// actions are handled (`UNUserNotificationCenterDelegate`, also the app —
/// but iOS can invoke it without launching into the foreground first).
public enum NotificationIdentifiers {
    public static let checkInCategory = "CHECKIN_CATEGORY"
    public static let checkInYesAction = "CHECKIN_YES"
    public static let checkInSomethingElseAction = "CHECKIN_SOMETHING_ELSE"

    public static let returnCategory = "RETURN_CATEGORY"
    public static let returnBackAction = "RETURN_BACK"
    public static let returnExtendAction = "RETURN_EXTEND"

    public static let checkInInfoKey = "checkInIdentifier"

    /// Fixed (not per-instance) since Fokus has at most one windup notice
    /// pending at a time — scheduling again with this identifier just
    /// replaces whatever was there.
    public static let fokusWindupIdentifier = "FOKUS_WINDUP"
}

/// Schedules the local notifications that make check-ins and return
/// prompts work even when the app isn't running. No sound is ever used —
/// only `.timeSensitive` visual/haptic delivery, per the app's design
/// constraint that check-ins are never alarms.
public struct NotificationScheduler {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    /// Registers the "Ja, dabei" / "Etwas anderes" and "Zurück" / "Noch X
    /// Minuten" actions so they can be answered directly from the
    /// notification, without opening the app.
    public func registerCategories() {
        let yes = UNNotificationAction(
            identifier: NotificationIdentifiers.checkInYesAction,
            title: "Ja, dabei",
            options: []
        )
        let somethingElse = UNNotificationAction(
            identifier: NotificationIdentifiers.checkInSomethingElseAction,
            title: "Etwas anderes",
            options: [.foreground]
        )
        let checkInCategory = UNNotificationCategory(
            identifier: NotificationIdentifiers.checkInCategory,
            actions: [yes, somethingElse],
            intentIdentifiers: [],
            options: []
        )

        let back = UNNotificationAction(
            identifier: NotificationIdentifiers.returnBackAction,
            title: "Zurück",
            options: []
        )
        let extend = UNNotificationAction(
            identifier: NotificationIdentifiers.returnExtendAction,
            title: "Noch etwas Zeit",
            options: [.foreground]
        )
        let returnCategory = UNNotificationCategory(
            identifier: NotificationIdentifiers.returnCategory,
            actions: [back, extend],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([checkInCategory, returnCategory])
    }

    public func scheduleCheckIn(identifier: String = UUID().uuidString, intentionText: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Bist du noch dabei?"
        content.body = intentionText
        content.categoryIdentifier = NotificationIdentifiers.checkInCategory
        content.interruptionLevel = .timeSensitive
        content.sound = nil
        content.userInfo = [NotificationIdentifiers.checkInInfoKey: identifier]

        await schedule(identifier: identifier, content: content, fireDate: fireDate)
    }

    public func scheduleReturnPrompt(identifier: String = UUID().uuidString, originalIntentionText: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Zurück zu:"
        content.body = originalIntentionText
        content.categoryIdentifier = NotificationIdentifiers.returnCategory
        content.interruptionLevel = .timeSensitive
        content.sound = nil

        await schedule(identifier: identifier, content: content, fireDate: fireDate)
    }

    /// Fokus's "5 min before end" heads-up (§ Anker/Fokus redesign) — purely
    /// informational, no actions, no response expected.
    public func scheduleFokusWindup(fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Noch 5 Minuten"
        content.body = "Dein Fokus-Block geht bald zu Ende."
        content.interruptionLevel = .timeSensitive
        content.sound = nil

        await schedule(identifier: NotificationIdentifiers.fokusWindupIdentifier, content: content, fireDate: fireDate)
    }

    public func cancelPending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func cancelAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    private func schedule(identifier: String, content: UNMutableNotificationContent, fireDate: Date) async {
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
