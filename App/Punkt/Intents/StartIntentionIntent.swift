import AppIntents
import IntentionCore

/// "Ich mache jetzt ___" (§9): a Siri Shortcut / App Intent that starts a
/// session directly. Runs in the app process (not `.foregroundContinuable`
/// only where needed) so it can reach the live `SessionStore` via a
/// well-known holder set up at launch.
struct StartIntentionIntent: AppIntent {
    static var title: LocalizedStringResource = "Ich mache jetzt …"
    static var description = IntentDescription("Startet eine neue Intention-Session.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Intention")
    var intentionText: String

    @Parameter(title: "Modus", default: .vertiefung)
    var mode: IntentSessionMode

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = SessionStoreHolder.shared else {
            return .result(dialog: "Die App muss einmal geöffnet werden, bevor Siri Sessions starten kann.")
        }
        store.startSession(intentionText: intentionText, mode: mode.sessionMode)
        return .result(dialog: "Los geht's: \(intentionText).")
    }
}

/// `SessionMode` isn't itself an `AppEnum` (it lives in the platform-agnostic
/// core); this is the thin App Intents-facing mirror.
enum IntentSessionMode: String, AppEnum {
    case vertiefung
    case wachheit

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Modus"
    static var caseDisplayRepresentations: [IntentSessionMode: DisplayRepresentation] = [
        .vertiefung: "Vertiefung",
        .wachheit: "Wachheit"
    ]

    var sessionMode: SessionMode {
        switch self {
        case .vertiefung: return .vertiefung
        case .wachheit: return .wachheit
        }
    }
}

/// A process-wide handle to the running app's `SessionStore`, so App
/// Intents (which are instantiated fresh by the system) can reach it.
/// `PunktApp.init` sets this once at launch.
@MainActor
enum SessionStoreHolder {
    static var shared: SessionStore?
}

struct PunktShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // `intentionText` is a plain String parameter, and Siri phrases can
        // only embed parameters that conform to AppEntity or AppEnum (it
        // needs a structured, enumerable value to parse from speech) — so
        // the free-text intention isn't part of the phrase itself. Siri
        // still prompts for it via `requestValueDialog`/the parameter's
        // own dialog after the phrase is matched.
        AppShortcut(
            intent: StartIntentionIntent(),
            phrases: [
                "Ich mache jetzt eine Intention in \(.applicationName)",
                "Starte eine Intention in \(.applicationName)"
            ],
            shortTitle: "Intention starten",
            systemImageName: "circle"
        )
    }
}
