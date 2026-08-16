import SwiftUI
import IntentionCore

/// The app is deliberately thin (§5.3): four screens, no more.
struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

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
        .onAppear { store.refreshAfterForeground() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.refreshAfterForeground()
            }
        }
    }
}

/// LEERLAUF vs. AKTIV router, with KORREKTUR / CHECK_IN / RÜCKKEHR_PROMPT
/// layered as sheets driven purely by the engine's phase.
private struct StartTabView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        Group {
            if store.session == nil {
                IntentionEntryView()
            } else {
                ActiveSessionView()
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
