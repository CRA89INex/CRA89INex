import Foundation
import IntentionCore

/// The three choices on the entry screen: Flow (no `SessionMode` of its
/// own — see `FlowSessionEngine`) plus the two check-in-based
/// `SessionMode` cases. Shared between `IntentionEntryView` (the picker
/// itself) and `SettingsView` (the "Standard-Modus" default) so both
/// agree on ordering, titles, and persisted raw values.
enum EntryMode: String, CaseIterable, Identifiable {
    case flow
    case fokus
    case anker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flow: return "Flow"
        case .fokus: return "Fokus"
        case .anker: return "Anker"
        }
    }

    var sessionMode: SessionMode? {
        switch self {
        case .flow: return nil
        case .fokus: return .fokus
        case .anker: return .anker
        }
    }
}
