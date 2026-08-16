import AppIntents
import IntentionCore

/// Live Activity / Dynamic Island buttons (§5.1) run inside the widget
/// extension process, so they can't touch the app's live `SessionEngine`
/// directly. Each intent records what was tapped in the App Group; the app
/// applies it on next foreground via `SessionStore.refreshAfterForeground`
/// (see `PendingActionStore`).
struct AnswerCheckInYesIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ja, dabei"

    func perform() async throws -> some IntentResult {
        PendingActionStore().write(.checkInYes)
        return .result()
    }
}

struct AnswerCheckInSomethingElseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Etwas anderes"

    func perform() async throws -> some IntentResult {
        PendingActionStore().write(.checkInNo)
        return .result()
    }
}

struct ConfirmReturnIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Zurück"

    func perform() async throws -> some IntentResult {
        PendingActionStore().write(.returnBack)
        return .result()
    }
}

struct ExtendDetourIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Noch etwas Zeit"

    func perform() async throws -> some IntentResult {
        PendingActionStore().write(.returnExtend)
        return .result()
    }
}
