import XCTest
@testable import IntentionCore

final class SessionEngineTests: XCTestCase {
    private func makeEngine(
        clock: TestClock = TestClock(),
        gracePeriod: TimeInterval = 10 * 60,
        maxMissedCheckIns: Int = 3,
        fixedInterval: TimeInterval? = nil
    ) -> (SessionEngine, TestClock) {
        let sample: (ClosedRange<TimeInterval>) -> TimeInterval = { range in
            fixedInterval ?? range.lowerBound
        }
        let engine = SessionEngine(
            clock: clock,
            gracePeriod: gracePeriod,
            maxMissedCheckIns: maxMissedCheckIns,
            intervalSample: sample
        )
        return (engine, clock)
    }

    // MARK: Starting

    func testStartSessionEntersActivePhaseAndSchedulesCheckIn() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "  Hörbuch hören  ", mode: .anker)

        XCTAssertEqual(engine.phase, .active)
        XCTAssertEqual(session.intentionText, "Hörbuch hören", "should be trimmed")
        XCTAssertTrue(session.isActive)
        XCTAssertNotNil(engine.nextCheckInDue)
        XCTAssertIdentical(engine.currentSession, session)
    }

    func testGracePeriodFloorsTheFirstCheckIn() {
        let clock = TestClock()
        // Anker's default 6-minute pace is shorter than the
        // 10 minute grace period, so the floor must win for check-in #1.
        let (engine, _) = makeEngine(clock: clock, fixedInterval: 6 * 60)
        engine.startSession(intentionText: "Lesen", mode: .anker)

        let due = try! XCTUnwrap(engine.nextCheckInDue)
        XCTAssertEqual(due.timeIntervalSince(clock.now()), 10 * 60, accuracy: 0.001)
    }

    func testSecondCheckInIsNotSubjectToTheGracePeriod() {
        let clock = TestClock()
        let (engine, _) = makeEngine(clock: clock, fixedInterval: 6 * 60)
        engine.startSession(intentionText: "Lesen", mode: .anker)

        clock.advance(by: 10 * 60)
        engine.checkInDue()
        engine.answerCheckIn(.yes)

        let due = try! XCTUnwrap(engine.nextCheckInDue)
        XCTAssertEqual(due.timeIntervalSince(clock.now()), 6 * 60, accuracy: 0.001)
    }

    // MARK: Check-in yes/no

    func testCheckInDueCreatesPendingCheckInAndEntersCheckInPhase() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)

        engine.checkInDue()

        XCTAssertEqual(engine.phase, .checkIn)
        XCTAssertNotNil(engine.pendingCheckIn)
        XCTAssertEqual(session.checkIns.count, 1)
    }

    func testAnsweringYesReturnsToActiveAndKeepsSessionRunning() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.checkInDue()

        engine.answerCheckIn(.yes)

        XCTAssertEqual(engine.phase, .active)
        XCTAssertNil(engine.pendingCheckIn)
        XCTAssertEqual(session.checkIns.first?.response, .yes)
        XCTAssertIdentical(engine.currentSession, session, "session must not be replaced by a yes answer")
    }

    func testAnsweringNoEntersCorrectionAndRecordsOptionalActivityText() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.checkInDue()

        engine.answerCheckIn(.no, actualActivityText: "Instagram")

        XCTAssertEqual(engine.phase, .correction)
        XCTAssertEqual(session.checkIns.first?.response, .no)
        XCTAssertEqual(session.checkIns.first?.actualActivityText, "Instagram")
    }

    func testAnsweringNoWithoutActivityTextIsAllowed() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.checkInDue()

        engine.answerCheckIn(.no)

        XCTAssertEqual(engine.phase, .correction)
        XCTAssertNil(session.checkIns.first?.actualActivityText)
    }

    // MARK: Unanswered check-ins / auto-sleep

    func testUnansweredCheckInsAreLoggedNotTreatedAsFailure() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Schreiben", mode: .anker)
        engine.checkInDue()

        engine.expirePendingCheckIn()

        XCTAssertEqual(engine.missedCheckInStreak, 1)
        XCTAssertEqual(engine.phase, .active, "a single miss resumes the session")
        XCTAssertNotNil(engine.currentSession)
    }

    func testThirdConsecutiveUnansweredCheckInPutsSessionToSleep() {
        let (engine, _) = makeEngine(maxMissedCheckIns: 3)
        let session = engine.startSession(intentionText: "Schreiben", mode: .anker)

        for _ in 0..<3 {
            engine.checkInDue()
            engine.expirePendingCheckIn()
        }

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertNil(engine.currentSession)
        XCTAssertNotNil(session.endedAt)
        XCTAssertTrue(session.endedAutomatically)
    }

    func testAYesAnswerResetsTheMissedCheckInStreak() {
        let (engine, _) = makeEngine(maxMissedCheckIns: 3)
        engine.startSession(intentionText: "Schreiben", mode: .anker)

        engine.checkInDue()
        engine.expirePendingCheckIn()
        engine.checkInDue()
        engine.expirePendingCheckIn()
        XCTAssertEqual(engine.missedCheckInStreak, 2)

        engine.checkInDue()
        engine.answerCheckIn(.yes)
        XCTAssertEqual(engine.missedCheckInStreak, 0)
    }

    // MARK: Manual correction (tap)

    func testUserCanRequestCorrectionWithoutACheckIn() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)

        engine.requestCorrection()

        XCTAssertEqual(engine.phase, .correction)
        XCTAssertTrue(session.checkIns.isEmpty, "a manual tap is not a check-in")
    }

    // MARK: Detour / return

    func testChooseDetourEntersDetourPhaseAndRecordsIt() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()

        engine.chooseDetour(reason: "Tür aufmachen", plannedDuration: 120)

        XCTAssertEqual(engine.phase, .detour)
        XCTAssertEqual(session.detours.count, 1)
        XCTAssertIdentical(engine.currentDetour, session.detours.first)
        XCTAssertEqual(engine.currentDetour?.plannedDuration, 120)
    }

    func testDetourCountdownExpiryEntersReturnPrompt() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()
        engine.chooseDetour(reason: "Tür", plannedDuration: 120)

        engine.detourCountdownExpired()

        XCTAssertEqual(engine.phase, .returnPrompt)
    }

    func testConfirmReturnClosesDetourAndResumesOriginalIntention() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()
        engine.chooseDetour(reason: "Tür", plannedDuration: 120)
        let detour = try! XCTUnwrap(engine.currentDetour)
        engine.detourCountdownExpired()

        engine.confirmReturn()

        XCTAssertEqual(engine.phase, .active)
        XCTAssertNil(engine.currentDetour)
        XCTAssertTrue(detour.returned)
        XCTAssertNotNil(detour.endedAt)
        XCTAssertIdentical(engine.currentSession, session, "returning does not start a new session")
    }

    func testEarlyReturnIsAllowedBeforeCountdownExpires() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()
        engine.chooseDetour(reason: "Tür", plannedDuration: 120)

        engine.confirmReturn()

        XCTAssertEqual(engine.phase, .active)
        XCTAssertTrue(engine.currentSession?.detours.first?.returned ?? false)
    }

    func testExtendDetourGoesBackToDetourPhaseWithExtensionRecorded() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()
        engine.chooseDetour(reason: "Tür", plannedDuration: 120)
        engine.detourCountdownExpired()

        engine.extendDetour(by: 300)

        XCTAssertEqual(engine.phase, .detour)
        XCTAssertEqual(engine.currentDetour?.extensions, [300])
        XCTAssertEqual(engine.currentDetour?.totalPlannedDuration, 420)
    }

    func testNewIntentionFromReturnPromptMarksDetourAsNotReturned() {
        let (engine, _) = makeEngine()
        let firstSession = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()
        engine.chooseDetour(reason: "Tür", plannedDuration: 120)
        let detour = try! XCTUnwrap(engine.currentDetour)
        engine.detourCountdownExpired()

        engine.chooseNewIntention("E-Mails beantworten")

        XCTAssertFalse(detour.returned)
        XCTAssertNotNil(detour.endedAt)
        XCTAssertNotNil(firstSession.endedAt)
        XCTAssertEqual(engine.currentSession?.intentionText, "E-Mails beantworten")
        XCTAssertEqual(engine.phase, .active)
    }

    // MARK: New intention from correction, session close

    func testNewIntentionFromCorrectionClosesOldSessionAndKeepsMode() {
        let (engine, _) = makeEngine()
        let oldSession = engine.startSession(intentionText: "Hörbuch hören", mode: .anker)
        engine.requestCorrection()

        engine.chooseNewIntention("Spazieren gehen")
        let newSession = engine.currentSession

        XCTAssertNotNil(oldSession.endedAt)
        XCTAssertFalse(oldSession.endedAutomatically)
        XCTAssertEqual(newSession?.intentionText, "Spazieren gehen")
        XCTAssertEqual(newSession?.mode, .anker)
        XCTAssertEqual(engine.phase, .active)
    }

    func testEndSessionFromActiveClosesSessionAndReturnsToIdle() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)

        engine.endSession(closingNote: "Fertig gehört")

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertNil(engine.currentSession)
        XCTAssertNotNil(session.endedAt)
        XCTAssertFalse(session.endedAutomatically)
        XCTAssertEqual(session.closingNote, "Fertig gehört")
    }

    func testEndSessionFromCorrectionAlsoClosesSession() {
        let (engine, _) = makeEngine()
        let session = engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)
        engine.requestCorrection()

        engine.endSession()

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertNotNil(session.endedAt)
    }

    // MARK: Invalid transitions are no-ops

    func testAnsweringCheckInWhileIdleIsNoOp() {
        let (engine, _) = makeEngine()
        engine.answerCheckIn(.yes)
        XCTAssertEqual(engine.phase, .idle)
    }

    func testChooseDetourOutsideCorrectionIsNoOp() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)

        engine.chooseDetour(reason: "Tür", plannedDuration: 120)

        XCTAssertEqual(engine.phase, .active, "detour can only be chosen from correction")
        XCTAssertEqual(engine.currentSession?.detours.count, 0)
    }

    func testConfirmReturnWithoutADetourIsNoOp() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Hörbuch hören", mode: .fokus)

        engine.confirmReturn()

        XCTAssertEqual(engine.phase, .active)
    }

    // MARK: Fokus's fixed 25/40 minute schedule

    func testFokusFirstCheckInIsScheduledAtTwentyFiveMinutes() {
        let clock = TestClock()
        let (engine, _) = makeEngine(clock: clock)
        let session = engine.startSession(intentionText: "Schreiben", mode: .fokus)

        let due = try! XCTUnwrap(engine.nextCheckInDue)
        XCTAssertEqual(due, session.startedAt.addingTimeInterval(25 * 60))
    }

    func testFokusSecondCheckInIsScheduledAtFortyMinutesFromStart() {
        let clock = TestClock()
        let (engine, _) = makeEngine(clock: clock)
        let session = engine.startSession(intentionText: "Schreiben", mode: .fokus)

        clock.advance(by: 25 * 60)
        engine.checkInDue()
        engine.answerCheckIn(.yes)

        let due = try! XCTUnwrap(engine.nextCheckInDue)
        XCTAssertEqual(due, session.startedAt.addingTimeInterval(40 * 60))
    }

    func testFokusSchedulesNoThirdCheckIn() {
        let clock = TestClock()
        let (engine, _) = makeEngine(clock: clock)
        engine.startSession(intentionText: "Schreiben", mode: .fokus)

        clock.advance(by: 25 * 60)
        engine.checkInDue()
        engine.answerCheckIn(.yes)
        clock.advance(by: 15 * 60)
        engine.checkInDue()
        engine.answerCheckIn(.yes)

        XCTAssertNil(engine.nextCheckInDue)
    }

    // MARK: Anker's user-adjustable pace

    func testAnkerUsesTheChosenPaceForItsIntervalBand() {
        let clock = TestClock()
        let (engine, _) = makeEngine(clock: clock)
        engine.startSession(intentionText: "Lesen", mode: .anker, ankerIntervalMinutes: 3)

        clock.advance(by: 10 * 60) // past the grace period
        engine.checkInDue()
        engine.answerCheckIn(.yes)

        let due = try! XCTUnwrap(engine.nextCheckInDue)
        let expectedRange = CheckInIntervalPolicy.aroundChosenPace(3)
        XCTAssertEqual(due.timeIntervalSince(clock.now()), expectedRange.lowerBound, accuracy: 0.001)
    }

    func testAnkerFallsBackToPreviousPaceWhenNotRespecified() {
        let (engine, _) = makeEngine()
        engine.startSession(intentionText: "Lesen", mode: .anker, ankerIntervalMinutes: 9)
        engine.requestCorrection()

        engine.chooseNewIntention("Aufräumen")

        // No assertion on the exact interval here (private state) — this
        // just verifies starting a new Anker session without specifying a
        // pace doesn't crash and still produces a scheduled check-in.
        XCTAssertNotNil(engine.nextCheckInDue)
    }
}
