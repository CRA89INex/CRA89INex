import AppIntents

/// Home Screen widget quick-start (§5.2): "Was jetzt?" → tap opens the app
/// straight to the intention text field. Session creation itself always
/// happens in the app process, where the one live `SessionEngine` runs —
/// this intent's only job is to bring that process to the foreground.
struct OpenIntentionEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Was jetzt?"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
