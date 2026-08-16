import SwiftUI
import IntentionCore

/// RÜCKKEHR_PROMPT (§4): "Zurück zu: <Intention>?" once a detour's
/// countdown runs out. Three ways forward; doing nothing is logged, not
/// punished (§"Offene Entscheidungen" #5).
struct ReturnPromptView: View {
    @Environment(SessionStore.self) private var store
    @State private var showingNewIntention = false
    @State private var newIntentionText = ""

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            if showingNewIntention {
                newIntentionView
            } else {
                promptView
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private var promptView: some View {
        VStack(spacing: 20) {
            Text("Zurück zu:")
                .font(.subheadline)
                .foregroundStyle(PunktPalette.textSecondary)

            Text(store.session?.intentionText ?? "")
                .font(.title3)
                .foregroundStyle(PunktPalette.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    store.confirmReturn()
                } label: {
                    Text("Ja, zurück")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.active)

                HStack(spacing: 12) {
                    ForEach([2, 5, 10], id: \.self) { minutes in
                        Button("+\(minutes) min") {
                            store.extendDetour(by: TimeInterval(minutes * 60))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("Neue Intention") {
                    showingNewIntention = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var newIntentionView: some View {
        VStack(spacing: 16) {
            Text("Neue Intention")
                .font(.headline)
                .foregroundStyle(PunktPalette.textPrimary)

            TextField("Was jetzt?", text: $newIntentionText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit(start)

            Button("Starten") { start() }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.active)
                .disabled(newIntentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Zurück") { showingNewIntention = false }
                .font(.footnote)
                .foregroundStyle(PunktPalette.textSecondary)
        }
    }

    private func start() {
        guard !newIntentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.chooseNewIntention(newIntentionText)
    }
}
