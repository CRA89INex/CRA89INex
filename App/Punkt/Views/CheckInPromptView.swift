import SwiftUI
import IntentionCore

/// CHECK_IN (§4, §6): a question, not an alarm. "Nein" leads to an
/// optional, one-tap-skippable note about what's actually happening
/// (decision §"Offene Entscheidungen" #4) before handing off to KORREKTUR.
struct CheckInPromptView: View {
    @Environment(SessionStore.self) private var store
    @State private var showingActivityPrompt = false
    @State private var activityText = ""

    var body: some View {
        VStack(spacing: 28) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            if showingActivityPrompt {
                activityPrompt
            } else {
                question
            }
        }
        .padding(24)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private var question: some View {
        VStack(spacing: 20) {
            Text("Bist du noch dabei?")
                .font(.title3)
                .foregroundStyle(PunktPalette.textPrimary)

            if let intention = store.session?.intentionText {
                Text(intention)
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
            }

            HStack(spacing: 16) {
                Button {
                    Haptics.confirmation()
                    store.answerCheckIn(.yes)
                } label: {
                    Text("Ja, dabei")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.active)

                Button {
                    showingActivityPrompt = true
                } label: {
                    Text("Etwas anderes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var activityPrompt: some View {
        VStack(spacing: 16) {
            Text("Was ist es gerade? (optional)")
                .font(.subheadline)
                .foregroundStyle(PunktPalette.textSecondary)

            TextField("z. B. Instagram", text: $activityText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 16) {
                Button("Überspringen") {
                    store.answerCheckIn(.no)
                }
                .buttonStyle(.bordered)

                Button("Weiter") {
                    let trimmed = activityText.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.answerCheckIn(.no, actualActivityText: trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.detour)
            }
        }
    }
}
