import WidgetKit
import SwiftUI
import IntentionCore

struct PunktWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSessionSnapshot?
}

struct PunktWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PunktWidgetEntry {
        PunktWidgetEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PunktWidgetEntry) -> Void) {
        completion(PunktWidgetEntry(date: .now, snapshot: SharedStateStore().load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PunktWidgetEntry>) -> Void) {
        // `Text(timerInterval:)` updates itself without further reloads, so
        // one entry — refreshed again whenever the app calls
        // `WidgetCenter.shared.reloadAllTimelines()` on a state change — is enough.
        let entry = PunktWidgetEntry(date: .now, snapshot: SharedStateStore().load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct PunktWidget: Widget {
    let kind = "PunktWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PunktWidgetProvider()) { entry in
            PunktWidgetView(entry: entry)
                .containerBackground(PunktWidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Punkt")
        .description("Was jetzt? — dein Schnellstart und laufende Session.")
        .supportedFamilies([.systemSmall])
    }
}

struct PunktWidgetView: View {
    let entry: PunktWidgetEntry

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.phase != .idle {
            activeView(snapshot)
        } else {
            idleView
        }
    }

    private var idleView: some View {
        Button(intent: OpenIntentionEntryIntent()) {
            VStack(spacing: 10) {
                Circle()
                    .fill(PunktWidgetPalette.idle)
                    .frame(width: 28, height: 28)
                Text("Was jetzt?")
                    .font(.footnote)
                    .foregroundStyle(PunktWidgetPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func activeView(_ snapshot: SharedSessionSnapshot) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color(for: snapshot.phase))
                .frame(width: 24, height: 24)

            Text(timerInterval: snapshot.startedAt...Date.distantFuture, countsDown: false)
                .font(.caption.monospacedDigit())
                .foregroundStyle(PunktWidgetPalette.textPrimary)

            Text(snapshot.intentionText)
                .font(.caption2)
                .foregroundStyle(PunktWidgetPalette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .widgetURL(URL(string: "punkt://active"))
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

enum PunktWidgetPalette {
    static let background = Color.black
    static let active = Color(red: 0.32, green: 0.62, blue: 0.58)
    static let checkIn = Color(red: 0.55, green: 0.85, blue: 0.78)
    static let detour = Color(red: 0.82, green: 0.62, blue: 0.28)
    static let returnDue = Color(red: 0.92, green: 0.70, blue: 0.30)
    static let idle = Color(white: 0.4)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
}
