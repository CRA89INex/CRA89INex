import Foundation

/// Purely descriptive computations for the "Muster" screen.
///
/// Nothing here scores, ranks, or judges — it restates what happened in
/// counts and ratios so the person can draw their own conclusions.
public struct PatternAnalyzer {
    public init() {}

    /// Time under the declared intention divided by total session time.
    /// Detour time (however long it actually ran) counts against it,
    /// because the main clock never pauses for a detour.
    public func coherenceRatio(for session: Session, asOf now: Date = .now) -> Double {
        let total = session.totalDuration(asOf: now)
        guard total > 0 else { return 0 }
        let detourTime = session.detours.reduce(TimeInterval(0)) { $0 + ($1.actualDuration ?? 0) }
        let intentional = max(0, total - detourTime)
        return intentional / total
    }

    public func averageCoherence(for sessions: [Session], asOf now: Date = .now) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let ratios = sessions.map { coherenceRatio(for: $0, asOf: now) }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    /// How many closed detours were actually followed by a return, out of
    /// how many closed detours in total. E.g. "6 von 9".
    public func returnRate(for sessions: [Session]) -> (returned: Int, total: Int) {
        let closedDetours = sessions.flatMap(\.detours).filter { !$0.isOpen }
        let returned = closedDetours.filter(\.returned).count
        return (returned, closedDetours.count)
    }

    /// Average of (actual duration - planned duration) across closed
    /// detours. Positive means detours tend to run long.
    public func averageDetourOverrun(for sessions: [Session]) -> TimeInterval {
        let overruns = sessions.flatMap(\.detours).compactMap { detour -> TimeInterval? in
            guard let actual = detour.actualDuration else { return nil }
            return actual - detour.totalPlannedDuration
        }
        guard !overruns.isEmpty else { return 0 }
        return overruns.reduce(0, +) / Double(overruns.count)
    }

    public struct DriftEntry: Sendable, Equatable {
        public let activityText: String
        public let hourOfDay: Int
        public let at: Date
    }

    /// What people say they were actually doing when they answered "no",
    /// and at what hour — the freely offered part only, nothing inferred.
    public func driftMap(for sessions: [Session], calendar: Calendar = .current) -> [DriftEntry] {
        sessions
            .flatMap(\.checkIns)
            .filter { $0.response == .no }
            .compactMap { checkIn -> DriftEntry? in
                guard let text = checkIn.actualActivityText,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let hour = calendar.component(.hour, from: checkIn.at)
                return DriftEntry(activityText: text, hourOfDay: hour, at: checkIn.at)
            }
    }
}
