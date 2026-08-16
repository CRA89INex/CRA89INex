#if canImport(UIKit)
import UIKit

/// Foreground haptic feedback. When the app is backgrounded, the
/// notification's own delivery (via `NotificationScheduler`) is what the
/// person feels — iOS does not allow arbitrary background vibration.
///
/// Deliberately uses the gentlest generators available: a check-in is a
/// question, not an alarm.
@MainActor
public enum Haptics {
    public static func checkIn() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    public static func returnDue() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func confirmation() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
#endif
