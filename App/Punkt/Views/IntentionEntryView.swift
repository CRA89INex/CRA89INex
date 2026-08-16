import SwiftUI
import IntentionCore

/// LEERLAUF (§4): "Was jetzt?" — a single-line text field, a mode choice,
/// up to five recent intentions as tappable suggestions, and dictation for
/// when typing isn't practical.
struct IntentionEntryView: View {
    @Environment(SessionStore.self) private var store
    @State private var text = ""
    @State private var mode: SessionMode = .vertiefung
    @State private var dictation = DictationController()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            PunktPalette.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                BreathingDotView(color: PunktPalette.idle, diameter: 72)

                VStack(spacing: 16) {
                    HStack {
                        TextField("Was jetzt?", text: $text)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .foregroundStyle(PunktPalette.textPrimary)
                            .focused($fieldFocused)
                            .submitLabel(.go)
                            .onSubmit(start)
                            .onChange(of: dictation.transcript) { _, newValue in
                                text = newValue
                            }

                        Button {
                            dictation.toggle()
                        } label: {
                            Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                                .foregroundStyle(dictation.isRecording ? PunktPalette.detour : PunktPalette.textSecondary)
                        }
                        .accessibilityLabel(dictation.isRecording ? "Diktat stoppen" : "Diktat starten")
                    }
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24)

                    Picker("Modus", selection: $mode) {
                        Text("Vertiefung").tag(SessionMode.vertiefung)
                        Text("Wachheit").tag(SessionMode.wachheit)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .accessibilityHint("Vertiefung: seltene Check-ins. Wachheit: häufigere Check-ins.")
                }

                if !store.recentIntentions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.recentIntentions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    text = suggestion
                                    start()
                                }
                                .font(.footnote)
                                .foregroundStyle(PunktPalette.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
        .onAppear { fieldFocused = true }
    }

    private func start() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.startSession(intentionText: text, mode: mode)
        text = ""
    }
}
