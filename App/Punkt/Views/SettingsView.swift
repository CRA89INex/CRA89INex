import SwiftUI
import UIKit
import UserNotifications
import IntentionCore

/// EINSTELLUNGEN (§5.3): everything the app can be adjusted by, without
/// ever adding streaks, scores, or reminders about "missed" sessions.
struct SettingsView: View {
    @AppStorage("defaultMode") private var defaultModeRawValue = EntryMode.fokus.rawValue
    @State private var notificationsAuthorized: Bool?

    var body: some View {
        NavigationStack {
            ZStack {
                PunktPalette.background.ignoresSafeArea()

                List {
                    Section {
                        Button("Wie funktioniert's?") {
                            NotificationCenter.default.post(name: .showTutorial, object: nil)
                        }
                    }

                    Section("Standard-Modus") {
                        Picker("Modus", selection: $defaultModeRawValue) {
                            ForEach(EntryMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Benachrichtigungen") {
                        HStack {
                            Text("Check-ins")
                            Spacer()
                            Text(notificationsStatusText)
                                .foregroundStyle(PunktPalette.textSecondary)
                        }
                        Button("Systemeinstellungen öffnen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    Section {
                        Text("Kein Ton. Keine Streaks. Keine Bewertung. Diese App zählt nichts, außer der Zeit unter deiner erklärten Intention.")
                            .font(.footnote)
                            .foregroundStyle(PunktPalette.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Einstellungen")
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsAuthorized = settings.authorizationStatus == .authorized
        }
    }

    private var notificationsStatusText: String {
        switch notificationsAuthorized {
        case .some(true): return "aktiv"
        case .some(false): return "nicht erlaubt"
        case .none: return "…"
        }
    }
}
