import SwiftUI
import IntentionCore

/// The Flow-mode session screen: ring + wave + phase dots, mirroring the
/// ramp → flow → exit rhythm of the original Flow Tracker prototype.
/// Shown instead of `ActiveSessionView` whenever a Flow session is
/// running (see `RootView`).
struct FlowSessionView: View {
    @Environment(FlowSessionStore.self) private var flowStore

    var body: some View {
        VStack(spacing: 6) {
            Text(phaseLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(phaseColor)
                .animation(.easeInOut(duration: 0.8), value: flowStore.phase)
                .padding(.top, 8)

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                ZStack {
                    ProgressRingView(progress: progress(at: context.date), color: phaseColor, lineWidth: 5, diameter: 220)
                    VStack(spacing: 4) {
                        Text(digits(at: context.date))
                            .font(.system(size: 48, weight: .light))
                            .monospacedDigit()
                            .foregroundStyle(PunktPalette.textPrimary)
                        Text(sublabel)
                            .font(.caption)
                            .foregroundStyle(PunktPalette.textSecondary)
                    }
                }
            }

            if flowStore.phase == .flow {
                WaveView(color: PunktFlowPalette.flow)
                    .frame(width: 240)
                    .padding(.top, 28)
            }

            Text(statusMessage)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(PunktPalette.textPrimary)
                .frame(maxWidth: 280, minHeight: 60)
                .padding(.top, 20)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(dotColor(index))
                        .frame(width: dotWidth(index), height: 6)
                }
            }
            .padding(.top, 12)
            .animation(.easeInOut(duration: 0.4), value: flowStore.phase)

            Spacer()

            if flowStore.phase == .exit, let session = flowStore.flowSession {
                FlowSessionLogView(session: session)
                    .padding(.bottom, 12)
            }

            Button(action: handleButtonTap) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(phaseColor)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PunktPalette.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }

    // MARK: Derived state

    private var flowStartedAt: Date? {
        guard let session = flowStore.flowSession, let rampDuration = session.actualRampDuration else { return nil }
        return session.startedAt.addingTimeInterval(rampDuration)
    }

    private func digits(at date: Date) -> String {
        switch flowStore.phase {
        case .ramp:
            guard let rampEndsAt = flowStore.rampEndsAt else { return "—" }
            return formatted(max(0, rampEndsAt.timeIntervalSince(date)))
        case .flow:
            guard let flowStartedAt else { return "0:00" }
            return formatted(max(0, date.timeIntervalSince(flowStartedAt)))
        case .exit:
            return "✓"
        case .idle:
            return "—"
        }
    }

    private func progress(at date: Date) -> Double {
        switch flowStore.phase {
        case .ramp:
            guard let session = flowStore.flowSession, session.plannedRampDuration > 0,
                  let rampEndsAt = flowStore.rampEndsAt else { return 0 }
            let total = session.plannedRampDuration
            let elapsed = total - max(0, rampEndsAt.timeIntervalSince(date))
            return min(1, max(0, elapsed / total))
        case .flow, .exit:
            return 1
        case .idle:
            return 0
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    private var phaseLabel: String {
        switch flowStore.phase {
        case .ramp: return "anlauf"
        case .flow: return "im flow"
        case .exit: return "ausklang"
        case .idle: return "bereit"
        }
    }

    private var phaseColor: Color {
        switch flowStore.phase {
        case .ramp: return PunktFlowPalette.ramp
        case .flow: return PunktFlowPalette.flow
        case .exit: return PunktFlowPalette.exit
        case .idle: return PunktPalette.idle
        }
    }

    private var sublabel: String {
        switch flowStore.phase {
        case .ramp: return "bis Flow"
        case .flow: return "im Flow"
        default: return ""
        }
    }

    private var statusMessage: String {
        switch flowStore.phase {
        case .ramp: return "Ankommen — lass die Gedanken fließen"
        case .flow: return "Ride the wave"
        case .exit: return "Gut gemacht — jetzt sanft landen"
        case .idle: return ""
        }
    }

    private var buttonTitle: String {
        switch flowStore.phase {
        case .ramp: return "Bin schon im Flow"
        case .flow: return "Konzentration verloren"
        case .exit: return "Neu starten"
        case .idle: return "Start"
        }
    }

    private func handleButtonTap() {
        switch flowStore.phase {
        case .ramp: flowStore.skipToFlow()
        case .flow: flowStore.endFlow()
        case .exit: flowStore.reset()
        case .idle: break
        }
    }

    private var activeDotCount: Int {
        switch flowStore.phase {
        case .ramp: return 1
        case .flow: return 2
        case .exit: return 3
        case .idle: return 0
        }
    }

    private func dotColor(_ index: Int) -> Color {
        if index < activeDotCount - 1 { return PunktFlowPalette.flow }
        if index == activeDotCount - 1 { return PunktPalette.textSecondary }
        return PunktPalette.textSecondary.opacity(0.2)
    }

    private func dotWidth(_ index: Int) -> CGFloat {
        index == activeDotCount - 1 ? 18 : 6
    }
}

private struct FlowSessionLogView: View {
    let session: FlowSession

    var body: some View {
        VStack(spacing: 6) {
            row(label: "Anlauf", value: minutesText(session.actualRampDuration))
            row(label: "Flow", value: minutesText(session.flowDuration))
            row(label: "Gesamt", value: minutesText(totalDuration))
        }
        .padding(14)
        .frame(maxWidth: 320)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 24)
    }

    private var totalDuration: TimeInterval? {
        guard session.actualRampDuration != nil || session.flowDuration != nil else { return nil }
        return (session.actualRampDuration ?? 0) + (session.flowDuration ?? 0)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(PunktPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(PunktPalette.textPrimary)
        }
    }

    private func minutesText(_ interval: TimeInterval?) -> String {
        guard let interval else { return "—" }
        return "\(Int((interval / 60).rounded())) min"
    }
}
