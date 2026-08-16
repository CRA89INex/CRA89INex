import SwiftUI
import IntentionCore

/// The main visualization (§5.3, §6): a breathing dot inside a soft
/// progress ring, the intention text as the quiet anchor beneath it, and —
/// during a detour — a second, smaller dot that orbits the dimmed main one.
struct ActiveSessionView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        if let session = store.session {
            SessionVisualizationView(session: session)
        } else {
            EmptyView()
        }
    }
}

private struct SessionVisualizationView: View {
    @Environment(SessionStore.self) private var store
    let session: Session

    private let referencePeriod: TimeInterval = 60 * 60 // one lap per hour

    var body: some View {
        ZStack {
            PunktPalette.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    ZStack {
                        ProgressRingView(
                            progress: lapProgress(
                                startedAt: session.startedAt,
                                now: context.date,
                                referencePeriod: referencePeriod
                            ),
                            color: dotColor
                        )

                        if store.phase == .detour || store.phase == .returnPrompt, let detour = store.detour {
                            DetourOrbitView(detour: detour, now: context.date)
                        }

                        BreathingDotView(color: dotColor)
                    }
                }

                VStack(spacing: 6) {
                    Text(session.intentionText)
                        .font(.body)
                        .foregroundStyle(PunktPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(session.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PunktPalette.textSecondary)
                }
                .padding(.horizontal, 32)

                if let detour = store.detour, store.phase == .detour {
                    Text("Exkurs: \(detour.reason)")
                        .font(.footnote)
                        .foregroundStyle(PunktPalette.detour)
                }

                Spacer()

                Button("Session beenden") {
                    store.endSession()
                }
                .font(.footnote)
                .foregroundStyle(PunktPalette.textSecondary)
                .padding(.bottom, 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if store.phase == .active {
                store.requestCorrection()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Zum Innehalten tippen")
        .accessibilityAddTraits(.isButton)
    }

    private var dotColor: Color {
        switch store.phase {
        case .active: return PunktPalette.active
        case .checkIn: return PunktPalette.checkIn
        case .detour: return PunktPalette.detour
        case .returnPrompt: return PunktPalette.returnDue
        default: return PunktPalette.idle
        }
    }

    private var accessibilityDescription: String {
        switch store.phase {
        case .active: return "Aktiv: \(session.intentionText)"
        case .checkIn: return "Check-in: Bist du noch dabei bei \(session.intentionText)?"
        case .detour: return "Exkurs läuft, ursprüngliche Intention: \(session.intentionText)"
        case .returnPrompt: return "Rückkehr fällig zu: \(session.intentionText)"
        default: return session.intentionText
        }
    }
}

/// The smaller, second dot that detaches during a detour (§6): its own
/// countdown, while the main dot stays visible but dimmed underneath.
private struct DetourOrbitView: View {
    let detour: Detour
    let now: Date

    var body: some View {
        let remaining = max(0, detour.currentCountdownEnd.timeIntervalSince(now))
        let angle = Angle.degrees(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 8) / 8 * 360)

        ZStack {
            Circle()
                .fill(PunktPalette.detour)
                .frame(width: 36, height: 36)
                .offset(x: 90)
                .rotationEffect(angle)
                .shadow(color: PunktPalette.detour.opacity(0.6), radius: 10)

            Text(formatted(remaining))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(PunktPalette.textSecondary)
                .offset(y: 130)
        }
        .accessibilityHidden(true)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
