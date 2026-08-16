import SwiftUI
import SwiftData
import IntentionCore

/// MUSTER (§5.3, §8): purely descriptive numbers, phrased as observations
/// ("In 6 von 9 Fällen…") rather than scores.
struct PatternsView: View {
    @Query(filter: #Predicate<Session> { $0.endedAt != nil }, sort: \Session.startedAt, order: .reverse)
    private var sessions: [Session]

    private let analyzer = PatternAnalyzer()

    var body: some View {
        NavigationStack {
            ZStack {
                PunktPalette.background.ignoresSafeArea()

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Muster",
                        systemImage: "chart.bar",
                        description: Text("Sobald ein paar Sessions abgeschlossen sind, siehst du hier, was sich zeigt.")
                    )
                } else {
                    List {
                        Section {
                            metric(
                                title: "Kohärenzquote (Wochenschnitt)",
                                value: "\(Int(analyzer.averageCoherence(for: recentSessions) * 100))%"
                            )
                            metric(
                                title: "Rückkehrquote",
                                value: returnRateText
                            )
                            metric(
                                title: "Exkurs-Überziehung (Schnitt)",
                                value: overrunText
                            )
                        }
                        .listRowBackground(Color.white.opacity(0.04))

                        if !driftEntries.isEmpty {
                            Section("Driftlandkarte") {
                                ForEach(Array(driftEntries.prefix(10).enumerated()), id: \.offset) { _, entry in
                                    HStack {
                                        Text(entry.activityText)
                                            .foregroundStyle(PunktPalette.textPrimary)
                                        Spacer()
                                        Text("\(entry.hourOfDay):00 Uhr")
                                            .foregroundStyle(PunktPalette.textSecondary)
                                    }
                                    .font(.footnote)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Muster")
        }
    }

    private var recentSessions: [Session] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return sessions.filter { $0.startedAt >= weekAgo }
    }

    private var returnRateText: String {
        let rate = analyzer.returnRate(for: sessions)
        guard rate.total > 0 else { return "noch keine Exkurse" }
        return "in \(rate.returned) von \(rate.total) Fällen bist du zurückgekehrt"
    }

    private var overrunText: String {
        let overrun = analyzer.averageDetourOverrun(for: sessions)
        let minutes = Int(overrun) / 60
        if minutes == 0 { return "wie geplant" }
        return minutes > 0 ? "durchschnittlich \(minutes) min länger als geplant" : "durchschnittlich \(-minutes) min kürzer als geplant"
    }

    private var driftEntries: [PatternAnalyzer.DriftEntry] {
        analyzer.driftMap(for: sessions).sorted { $0.at > $1.at }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(PunktPalette.textSecondary)
            Text(value)
                .font(.title3)
                .foregroundStyle(PunktPalette.textPrimary)
        }
        .padding(.vertical, 4)
    }
}
