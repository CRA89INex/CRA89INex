import SwiftUI
import IntentionCore

/// KORREKTUR (§4): "Was ist gerade?" — exactly three ways forward, no
/// judgment attached to any of them.
struct CorrectionSheet: View {
    @Environment(SessionStore.self) private var store
    @State private var mode: Mode = .choice

    private enum Mode {
        case choice
        case detour
        case newIntention
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            switch mode {
            case .choice:
                choiceView
            case .detour:
                DetourDurationPickerView(onBack: { mode = .choice })
            case .newIntention:
                NewIntentionPickerView(onBack: { mode = .choice })
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private var choiceView: some View {
        VStack(spacing: 16) {
            Text("Was ist gerade?")
                .font(.title3)
                .foregroundStyle(PunktPalette.textPrimary)

            if let intention = store.session?.intentionText {
                Text("Bisherige Intention: \(intention)")
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
            }

            VStack(spacing: 12) {
                Button {
                    mode = .detour
                } label: {
                    Label("Kurzer Exkurs", systemImage: "arrow.turn.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.detour)

                Button {
                    mode = .newIntention
                } label: {
                    Label("Neue Intention", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    store.endSession()
                } label: {
                    Label("Session beenden", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// The three quick-pick durations plus a free entry (§9).
struct DetourDurationPickerView: View {
    @Environment(SessionStore.self) private var store
    var onBack: () -> Void

    @State private var reason = ""
    @State private var customMinutes: Double = 7

    var body: some View {
        VStack(spacing: 16) {
            Text("Kurzer Exkurs")
                .font(.headline)
                .foregroundStyle(PunktPalette.textPrimary)

            TextField("Was machst du kurz? (optional)", text: $reason)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                ForEach([2, 5, 15], id: \.self) { minutes in
                    Button("\(minutes) min") {
                        start(minutes: Double(minutes))
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack {
                Text("Frei: \(Int(customMinutes)) min")
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
                Slider(value: $customMinutes, in: 1...30, step: 1)
                Button("Los") { start(minutes: customMinutes) }
                    .buttonStyle(.borderedProminent)
                    .tint(PunktPalette.detour)
            }

            Button("Zurück", action: onBack)
                .font(.footnote)
                .foregroundStyle(PunktPalette.textSecondary)
        }
    }

    private func start(minutes: Double) {
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        store.chooseDetour(
            reason: cleanReason.isEmpty ? "Exkurs" : cleanReason,
            plannedDuration: minutes * 60
        )
    }
}

private struct NewIntentionPickerView: View {
    @Environment(SessionStore.self) private var store
    var onBack: () -> Void

    @State private var text = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Neue Intention")
                .font(.headline)
                .foregroundStyle(PunktPalette.textPrimary)

            TextField("Was jetzt?", text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit(start)

            Button("Starten") { start() }
                .buttonStyle(.borderedProminent)
                .tint(PunktPalette.active)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Zurück", action: onBack)
                .font(.footnote)
                .foregroundStyle(PunktPalette.textSecondary)
        }
    }

    private func start() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.chooseNewIntention(text)
    }
}
