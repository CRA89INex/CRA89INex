import SwiftUI
import SwiftData
import UserNotifications
import IntentionCore

@main
struct PunktApp: App {
    private let modelContainer: ModelContainer
    @State private var sessionStore: SessionStore
    private let notificationDelegate: NotificationDelegate

    init() {
        let schema = Schema([Session.self, CheckIn.self, Detour.self])
        let configuration: ModelConfiguration
        if let groupURL = AppGroup.modelStoreURL {
            configuration = ModelConfiguration(schema: schema, url: groupURL)
        } else {
            // Falls back to the default (non-shared) store, e.g. in Xcode
            // previews or before the App Group entitlement is configured.
            configuration = ModelConfiguration(schema: schema)
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            container = try! ModelContainer(for: schema)
        }
        self.modelContainer = container

        let store = SessionStore(modelContext: container.mainContext)
        self._sessionStore = State(wrappedValue: store)
        SessionStoreHolder.shared = store

        let delegate = NotificationDelegate(sessionStore: store)
        self.notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate

        let scheduler = NotificationScheduler()
        Task {
            _ = await scheduler.requestAuthorization()
            scheduler.registerCategories()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
