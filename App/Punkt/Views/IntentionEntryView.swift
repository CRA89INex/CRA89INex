import SwiftUI
import IntentionCore

/// LEERLAUF (§4): "Was jetzt?" for the check-in modes (Fokus/Anker) — a
/// single-line text field, up to five recent intentions as tappable
/// suggestions, and dictation for when typing isn't practical. Flow is a
/// third choice here but has its own shape entirely (no intention text,
/// just a ramp duration) since it isn't a check-in session at all.
struct IntentionEntryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(FlowSessionStore.self) private var flowStore
    @AppStorage("defaultMode") private var defaultModeRawValue = EntryMode.fokus.rawValue
    @State private var text = ""
    @State private var entryMode: EntryMode = .fokus
    @State private var rampMinutes: Double = 15
    @State private var ankerIntervalMinutes: Double = 6
    @State private var dictation = DictationController()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            PunktPalette.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                BreathingDotView(color: dotColor, diameter: 72)

                VStack(spacing: 16) {
                    Picker("Modus", selection: $entryMode) {
                        ForEach(EntryMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .accessibilityHint("Flow: Anlauf, dann offene Flow-Zeit ohne Check-ins. Fokus: fester Arbeitsblock mit Check-ins nach 25 und 40 Minuten. Anker: häufige, einstellbare Check-ins.")

                    switch entryMode {
                    case .flow:
                        flowForm
                    case .fokus:
                        intentionForm
                    case .anker:
                        VStack(spacing: 16) {
                            intentionForm
                            ankerIntervalSlider
                        }
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
        .onAppear {
            entryMode = EntryMode(rawValue: defaultModeRawValue) ?? .fokus
            fieldFocused = entryMode != .flow
        }
        .onChange(of: entryMode) { _, newMode in
            fieldFocused = newMode != .flow
        }
    }

    private var dotColor: Color {
        switch entryMode {
        case .flow: return PunktFlowPalette.ramp.opacity(0.6)
        case .fokus, .anker: return PunktPalette.idle
        }
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

    private var ankerIntervalSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Impuls alle")
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
                Spacer()
                Text("\(Int(ankerIntervalMinutes)) min")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(PunktPalette.textPrimary)
            }
            Slider(value: $ankerIntervalMinutes, in: 3...12, step: 1)
                .tint(PunktPalette.checkIn)
        }
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
        guard let mode = entryMode.sessionMode else { return }
        store.startSession(
            intentionText: text,
            mode: mode,
            ankerIntervalMinutes: mode == .anker ? ankerIntervalMinutes : nil
        )
        text = ""
    }
}
