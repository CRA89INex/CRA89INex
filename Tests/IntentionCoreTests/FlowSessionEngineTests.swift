import XCTest
@testable import IntentionCore

final class FlowSessionEngineTests: XCTestCase {
    func testStartRampEntersRampPhaseAndSchedulesEnd() {
        let clock = TestClock()
        let engine = FlowSessionEngine(clock: clock)

        let session = engine.startRamp(plannedRampDuration: 15 * 60)

        XCTAssertEqual(engine.phase, .ramp)
        XCTAssertIdentical(engine.currentFlowSession, session)
        XCTAssertEqual(session.plannedRampDuration, 15 * 60)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(engine.rampEndsAt, clock.now().addingTimeInterval(15 * 60))
    }

    func testRampCountdownExpiryEntersFlowWithoutSkip() {
        let clock = TestClock()
        let engine = FlowSessionEngine(clock: clock)
        let session = engine.startRamp(plannedRampDuration: 15 * 60)
        clock.advance(by: 15 * 60)

        engine.rampCountdownExpired()

        XCTAssertEqual(engine.phase, .flow)
        XCTAssertNil(engine.rampEndsAt)
        XCTAssertFalse(session.skippedRamp)
        XCTAssertEqual(session.actualRampDuration, 15 * 60, accuracy: 0.001)
    }

    func testSkipToFlowEndsRampEarlyAndMarksSkipped() {
        let clock = TestClock()
        let engine = FlowSessionEngine(clock: clock)
        let session = engine.startRamp(plannedRampDuration: 15 * 60)
        clock.advance(by: 5 * 60)

        engine.skipToFlow()

        XCTAssertEqual(engine.phase, .flow)
        XCTAssertTrue(session.skippedRamp)
        XCTAssertEqual(session.actualRampDuration, 5 * 60, accuracy: 0.001)
    }

    func testEndFlowRecordsFlowDurationAndEntersExit() {
        let clock = TestClock()
        let engine = FlowSessionEngine(clock: clock)
        let session = engine.startRamp(plannedRampDuration: 10 * 60)
        clock.advance(by: 10 * 60)
        engine.rampCountdownExpired()
        clock.advance(by: 42 * 60)

        engine.endFlow()

        XCTAssertEqual(engine.phase, .exit)
        XCTAssertEqual(session.flowDuration, 42 * 60, accuracy: 0.001)
        XCTAssertNotNil(session.endedAt)
        XCTAssertFalse(session.isActive)
    }

    func testResetReturnsToIdleAndClearsCurrentSession() {
        let clock = TestClock()
        let engine = FlowSessionEngine(clock: clock)
        engine.startRamp(plannedRampDuration: 60)
        engine.skipToFlow()
        engine.endFlow()

        engine.reset()

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertNil(engine.currentFlowSession)
        XCTAssertNil(engine.rampEndsAt)
    }

    // MARK: Invalid transitions are no-ops

    func testSkipToFlowOutsideRampIsNoOp() {
        let engine = FlowSessionEngine(clock: TestClock())
        engine.skipToFlow()
        XCTAssertEqual(engine.phase, .idle)
    }

    func testEndFlowOutsideFlowIsNoOp() {
        let engine = FlowSessionEngine(clock: TestClock())
        engine.startRamp(plannedRampDuration: 60)
        engine.endFlow()
        XCTAssertEqual(engine.phase, .ramp, "endFlow should not fire while still ramping")
    }

    func testResetOutsideExitIsNoOp() {
        let engine = FlowSessionEngine(clock: TestClock())
        engine.startRamp(plannedRampDuration: 60)
        engine.reset()
        XCTAssertEqual(engine.phase, .ramp)
        XCTAssertNotNil(engine.currentFlowSession)
    }

    func testRampCountdownExpiredIgnoredOnceAlreadyInFlow() {
        let engine = FlowSessionEngine(clock: TestClock())
        engine.startRamp(plannedRampDuration: 60)
        engine.skipToFlow()
        let sessionBefore = engine.currentFlowSession

        engine.rampCountdownExpired()

        XCTAssertEqual(engine.phase, .flow)
        XCTAssertIdentical(engine.currentFlowSession, sessionBefore)
    }
}
