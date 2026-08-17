import SwiftUI
import IntentionCore

/// LEERLAUF (§4): "Was jetzt?" for the check-in modes (Vertiefung/Wachheit)
/// — a single-line text field, up to five recent intentions as tappable
/// suggestions, and dictation for when typing isn't practical. Flow mode
/// is a third choice here but has its own shape entirely (no intention
/// text, just a ramp duration) since it isn't a check-in session at all.
struct IntentionEntryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(FlowSessionStore.self) private var flowStore
    @State private var text = ""
    @State private var entryMode: EntryMode = .vertiefung
    @State private var rampMinutes: Double = 15
    @State private var dictation = DictationController()
    @FocusState private var fieldFocused: Bool

    private enum EntryMode: Hashable {
        case vertiefung
        case wachheit
        case flow
    }

    var body: some View {
        ZStack {
            PunktPalette.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                BreathingDotView(color: dotColor, diameter: 72)

                VStack(spacing: 16) {
                    Picker("Modus", selection: $entryMode) {
                        Text("Vertiefung").tag(EntryMode.vertiefung)
                        Text("Wachheit").tag(EntryMode.wachheit)
                        Text("Flow").tag(EntryMode.flow)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .accessibilityHint("Vertiefung: seltene Check-ins. Wachheit: häufigere Check-ins. Flow: Anlauf, dann offene Flow-Zeit ohne Check-ins.")

                    if entryMode == .flow {
                        flowForm
                    } else {
                        intentionForm
                    }
                }

                if entryMode != .flow, !store.recentIntentions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.recentIntentions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    text = suggestion
                                    startIntention()
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
        .onAppear { fieldFocused = entryMode != .flow }
        .onChange(of: entryMode) { _, newMode in
            fieldFocused = newMode != .flow
        }
    }

    private var dotColor: Color {
        entryMode == .flow ? PunktFlowPalette.ramp.opacity(0.6) : PunktPalette.idle
    }

    private var intentionForm: some View {
        HStack {
            TextField("Was jetzt?", text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(PunktPalette.textPrimary)
                .focused($fieldFocused)
                .submitLabel(.go)
                .onSubmit(startIntention)
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
    }

    private var flowForm: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Text("Anlaufzeit")
                        .font(.footnote)
                        .foregroundStyle(PunktPalette.textSecondary)
                    Spacer()
                    Text("\(Int(rampMinutes)) min")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(PunktPalette.textPrimary)
                }
                Slider(value: $rampMinutes, in: 5...30, step: 1)
                    .tint(PunktFlowPalette.ramp)
            }
            .padding(.horizontal, 24)

            Button {
                flowStore.startRamp(duration: rampMinutes * 60)
            } label: {
                Text("Start")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(PunktFlowPalette.ramp)
            .padding(.horizontal, 24)
        }
    }

    private func startIntention() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let mode: SessionMode = entryMode == .wachheit ? .wachheit : .vertiefung
        store.startSession(intentionText: text, mode: mode)
        text = ""
    }
}
