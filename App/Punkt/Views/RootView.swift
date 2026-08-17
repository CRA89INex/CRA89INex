import SwiftUI
import IntentionCore

extension Notification.Name {
    /// Posted by `SettingsView`'s "Wie funktioniert's?" button so `RootView`
    /// (which owns the tutorial's presentation state) can reopen it from a
    /// different tab.
    static let showTutorial = Notification.Name("showTutorial")
}

/// The app is deliberately thin (§5.3): four screens, no more.
struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(FlowSessionStore.self) private var flowStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showingTutorial = false

    var body: some View {
        TabView {
            StartTabView()
                .tabItem { Label("Start", systemImage: "circle") }

            HistoryView()
                .tabItem { Label("Verlauf", systemImage: "list.bullet") }

            PatternsView()
                .tabItem { Label("Muster", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .tint(PunktPalette.active)
        .onAppear { refreshAfterForeground() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshAfterForeground()
            }
        }
    }

    private func refreshAfterForeground() {
        store.refreshAfterForeground()
        flowStore.refreshAfterForeground()
    }
}

/// LEERLAUF vs. AKTIV (intention or flow) router, with KORREKTUR /
/// CHECK_IN / RÜCKKEHR_PROMPT layered as sheets driven purely by the
/// engine's phase.
private struct StartTabView: View {
    @Environment(SessionStore.self) private var store
    @Environment(FlowSessionStore.self) private var flowStore

    var body: some View {
        Group {
            if flowStore.phase != .idle {
                FlowSessionView()
            } else if store.session != nil {
                ActiveSessionView()
            } else {
                IntentionEntryView()
            }
        }
        .sheet(isPresented: isCheckIn) { CheckInPromptView() }
        .sheet(isPresented: isCorrection) { CorrectionSheet() }
        .sheet(isPresented: isReturnPrompt) { ReturnPromptView() }
    }

    private var isCheckIn: Binding<Bool> {
        Binding(get: { store.phase == .checkIn }, set: { _ in })
    }
    private var isCorrection: Binding<Bool> {
        Binding(get: { store.phase == .correction }, set: { _ in })
    }
    private var isReturnPrompt: Binding<Bool> {
        Binding(get: { store.phase == .returnPrompt }, set: { _ in })
    }
}
