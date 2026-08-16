import XCTest
@testable import IntentionCore

final class PatternAnalyzerTests: XCTestCase {
    private let analyzer = PatternAnalyzer()
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func closedSession(
        detours: [(planned: TimeInterval, actual: TimeInterval, returned: Bool)] = [],
        duration: TimeInterval = 3600
    ) -> Session {
        let session = Session(intentionText: "Test", startedAt: start, mode: .vertiefung)
        session.endedAt = start.addingTimeInterval(duration)
        for spec in detours {
            let detour = Detour(reason: "x", plannedDuration: spec.planned, startedAt: start)
            detour.endedAt = start.addingTimeInterval(spec.actual)
            detour.returned = spec.returned
            session.detours.append(detour)
        }
        return session
    }

    func testCoherenceRatioWithNoDetoursIsOne() {
        let session = closedSession(duration: 1800)
        XCTAssertEqual(analyzer.coherenceRatio(for: session), 1.0, accuracy: 0.0001)
    }

    func testCoherenceRatioSubtractsDetourTimeFromTotal() {
        // 1h total, 10 min detour -> 50/60 intentional.
        let session = closedSession(detours: [(planned: 300, actual: 600, returned: true)], duration: 3600)
        XCTAssertEqual(analyzer.coherenceRatio(for: session), 3000.0 / 3600.0, accuracy: 0.0001)
    }

    func testCoherenceRatioOnEmptySessionIsZero() {
        let session = closedSession(duration: 0)
        XCTAssertEqual(analyzer.coherenceRatio(for: session), 0)
    }

    func testAverageCoherenceAcrossSessions() {
        let full = closedSession(duration: 1000)
        let half = closedSession(detours: [(planned: 500, actual: 500, returned: true)], duration: 1000)
        XCTAssertEqual(analyzer.averageCoherence(for: [full, half]), 0.75, accuracy: 0.0001)
    }

    func testReturnRateCountsOnlyClosedDetours() {
        let session = closedSession(detours: [
            (planned: 120, actual: 120, returned: true),
            (planned: 120, actual: 400, returned: false),
            (planned: 120, actual: 90, returned: true)
        ])
        let openDetour = Detour(reason: "open", plannedDuration: 60, startedAt: start)
        session.detours.append(openDetour) // endedAt stays nil

        let rate = analyzer.returnRate(for: [session])

        XCTAssertEqual(rate.total, 3, "the still-open detour must not be counted")
        XCTAssertEqual(rate.returned, 2)
    }

    func testAverageDetourOverrunIsPositiveWhenDetoursRunLong() {
        let session = closedSession(detours: [
            (planned: 120, actual: 180, returned: true), // +60
            (planned: 300, actual: 240, returned: true)  // -60
        ])
        XCTAssertEqual(analyzer.averageDetourOverrun(for: [session]), 0, accuracy: 0.0001)
    }

    func testDriftMapOnlyIncludesNoAnswersWithFreelyGivenText() {
        let session = Session(intentionText: "Test", startedAt: start, mode: .wachheit)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let atFourteen = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: start)!

        let withText = CheckIn(at: atFourteen, response: .no, actualActivityText: "Instagram")
        let skipped = CheckIn(at: atFourteen, response: .no, actualActivityText: nil)
        let blank = CheckIn(at: atFourteen, response: .no, actualActivityText: "   ")
        let yes = CheckIn(at: atFourteen, response: .yes, actualActivityText: "irrelevant")
        session.checkIns = [withText, skipped, blank, yes]

        let entries = analyzer.driftMap(for: [session], calendar: calendar)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.activityText, "Instagram")
        XCTAssertEqual(entries.first?.hourOfDay, 14)
    }
}
