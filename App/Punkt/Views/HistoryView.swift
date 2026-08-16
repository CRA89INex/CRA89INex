import SwiftUI
import SwiftData
import IntentionCore

/// VERLAUF (§5.3): closed sessions as a list, each expandable into a
/// timeline of its detours.
struct HistoryView: View {
    @Query(
        filter: #Predicate<Session> { $0.endedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var sessions: [Session]

    private let analyzer = PatternAnalyzer()

    var body: some View {
        NavigationStack {
            ZStack {
                PunktPalette.background.ignoresSafeArea()

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Noch kein Verlauf",
                        systemImage: "circle.dashed",
                        description: Text("Abgeschlossene Sessions erscheinen hier.")
                    )
                } else {
                    List(sessions) { session in
                        DisclosureGroup {
                            SessionTimelineView(session: session)
                        } label: {
                            SessionRow(session: session, coherence: analyzer.coherenceRatio(for: session))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Verlauf")
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let coherence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.intentionText)
                .foregroundStyle(PunktPalette.textPrimary)
            HStack {
                Text(session.startedAt, style: .date)
                Text("·")
                Text(durationText)
                Text("·")
                Text("\(Int(coherence * 100))% Kohärenz")
            }
            .font(.caption)
            .foregroundStyle(PunktPalette.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        let minutes = Int(session.totalDuration()) / 60
        return "\(minutes) min"
    }
}

private struct SessionTimelineView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.detours.isEmpty {
                Text("Kein Exkurs")
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
            } else {
                ForEach(session.detours.sorted(by: { $0.startedAt < $1.startedAt })) { detour in
                    HStack {
                        Circle()
                            .fill(detour.returned ? PunktPalette.active : PunktPalette.detour)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(detour.reason)
                                .font(.footnote)
                                .foregroundStyle(PunktPalette.textPrimary)
                            Text(detourSubtitle(detour))
                                .font(.caption2)
                                .foregroundStyle(PunktPalette.textSecondary)
                        }
                    }
                }
            }

            if let note = session.closingNote, !note.isEmpty {
                Text("„\(note)“")
                    .font(.footnote.italic())
                    .foregroundStyle(PunktPalette.textSecondary)
            }

            if session.endedAutomatically {
                Text("Automatisch eingeschlafen nach mehreren unbeantworteten Check-ins")
                    .font(.caption2)
                    .foregroundStyle(PunktPalette.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func detourSubtitle(_ detour: Detour) -> String {
        let planned = Int(detour.totalPlannedDuration) / 60
        guard let actual = detour.actualDuration else { return "geplant \(planned) min" }
        let actualMinutes = Int(actual) / 60
        return "geplant \(planned) min · tatsächlich \(actualMinutes) min · \(detour.returned ? "zurückgekehrt" : "nicht zurückgekehrt")"
    }
}
