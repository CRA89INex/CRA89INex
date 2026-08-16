import ActivityKit
import WidgetKit
import SwiftUI
import IntentionCore

/// §5.1 — the app's real "everywhere" surface: Lock Screen and Dynamic
/// Island, visible without opening the app.
struct PunktLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntentionActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(PunktWidgetPalette.background)
                .activitySystemActionForegroundColor(PunktWidgetPalette.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Circle()
                        .fill(color(for: context.state.phase))
                        .frame(width: 14, height: 14)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PunktWidgetPalette.textPrimary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.intentionText)
                        .font(.caption)
                        .foregroundStyle(PunktWidgetPalette.textSecondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.phase == .checkIn {
                        HStack {
                            Button(intent: AnswerCheckInYesIntent()) {
                                Text("Ja, dabei")
                            }
                            Button(intent: AnswerCheckInSomethingElseIntent()) {
                                Text("Etwas anderes")
                            }
                        }
                        .font(.caption2)
                    } else if context.state.phase == .returnPrompt {
                        HStack {
                            Button(intent: ConfirmReturnIntent()) {
                                Text("Zurück")
                            }
                            Button(intent: ExtendDetourIntent()) {
                                Text("Noch etwas Zeit")
                            }
                        }
                        .font(.caption2)
                    } else if context.state.phase == .detour, let end = context.state.detourCountdownEnd {
                        Text(timerInterval: Date.now...end, countsDown: true)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(PunktWidgetPalette.detour)
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(color(for: context.state.phase))
                    .frame(width: 10, height: 10)
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PunktWidgetPalette.textPrimary)
            } minimal: {
                Circle()
                    .fill(color(for: context.state.phase))
            }
        }
    }

    private func color(for phase: SessionPhaseSnapshot) -> Color {
        switch phase {
        case .active: return PunktWidgetPalette.active
        case .checkIn: return PunktWidgetPalette.checkIn
        case .detour: return PunktWidgetPalette.detour
        case .returnPrompt: return PunktWidgetPalette.returnDue
        case .idle, .correction: return PunktWidgetPalette.idle
        }
    }
}

/// The full Lock Screen visualization: ring + intention text, and — during
/// a detour — the countdown with the original intention dimmed beneath it.
private struct LockScreenView: View {
    let state: IntentionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(PunktWidgetPalette.textPrimary)

                Text(state.intentionText)
                    .font(.caption)
                    .foregroundStyle(state.phase == .detour ? PunktWidgetPalette.textSecondary.opacity(0.6) : PunktWidgetPalette.textSecondary)
                    .lineLimit(1)

                if state.phase == .detour, let reason = state.detourReason {
                    Text("Exkurs: \(reason)")
                        .font(.caption2)
                        .foregroundStyle(PunktWidgetPalette.detour)
                }
            }

            Spacer()

            if state.phase == .detour, let end = state.detourCountdownEnd {
                Text(timerInterval: Date.now...end, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PunktWidgetPalette.detour)
            } else {
                Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PunktWidgetPalette.textPrimary)
            }
        }
        .padding()
    }

    private var color: Color {
        switch state.phase {
        case .active: return PunktWidgetPalette.active
        case .checkIn: return PunktWidgetPalette.checkIn
        case .detour: return PunktWidgetPalette.detour
        case .returnPrompt: return PunktWidgetPalette.returnDue
        case .idle, .correction: return PunktWidgetPalette.idle
        }
    }

    private var headline: String {
        switch state.phase {
        case .checkIn: return "Bist du noch dabei?"
        case .returnPrompt: return "Zurück zu:"
        default: return "Aktiv"
        }
    }
}
