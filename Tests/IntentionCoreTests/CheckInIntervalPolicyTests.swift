import XCTest
@testable import IntentionCore

final class CheckInIntervalPolicyTests: XCTestCase {
    func testInitialDriftFactorIsNeutral() {
        let policy = CheckInIntervalPolicy(mode: .wachheit)
        XCTAssertEqual(policy.driftFactor, 1.0)
    }

    func testTwoConsecutiveYesAnswersDampenTheCadence() {
        var policy = CheckInIntervalPolicy(mode: .wachheit)
        policy.recordAnswer(.yes)
        XCTAssertEqual(policy.driftFactor, 1.0, "a single yes should not change anything yet")

        policy.recordAnswer(.yes)
        XCTAssertGreaterThan(policy.driftFactor, 1.0, "two yeses in a row should lengthen the interval")
    }

    func testNoCompressesTheCadence() {
        var policy = CheckInIntervalPolicy(mode: .wachheit)
        policy.recordAnswer(.yes)
        policy.recordAnswer(.yes)
        let dampened = policy.driftFactor

        policy.recordAnswer(.no)

        XCTAssertLessThan(policy.driftFactor, dampened)
        XCTAssertLessThan(policy.driftFactor, 1.0)
    }

    func testMissedDetourReturnAlsoCompressesTheCadence() {
        var policy = CheckInIntervalPolicy(mode: .vertiefung)
        policy.recordMissedDetourReturn()
        XCTAssertLessThan(policy.driftFactor, 1.0)
    }

    func testDriftFactorIsClamped() {
        var policy = CheckInIntervalPolicy(mode: .wachheit)
        for _ in 0..<20 {
            policy.recordAnswer(.yes)
            policy.recordAnswer(.yes)
        }
        XCTAssertLessThanOrEqual(policy.driftFactor, 3.0)

        for _ in 0..<20 {
            policy.recordAnswer(.no)
        }
        XCTAssertGreaterThanOrEqual(policy.driftFactor, 0.4)
    }

    func testUnansweredResetsTheYesStreakWithoutChangingDriftFactor() {
        var policy = CheckInIntervalPolicy(mode: .wachheit)
        policy.recordAnswer(.yes)
        policy.recordAnswer(.unanswered)
        policy.recordAnswer(.yes)
        // The streak was reset, so this single yes shouldn't have dampened yet.
        XCTAssertEqual(policy.driftFactor, 1.0)
    }

    func testNextIntervalUsesModeBandAndDriftFactor() {
        var policy = CheckInIntervalPolicy(mode: .vertiefung)
        policy.recordAnswer(.no) // driftFactor 0.6

        let interval = policy.nextInterval(sample: { _ in 20 * 60 })

        XCTAssertEqual(interval, 20 * 60 * 0.6, accuracy: 0.001)
    }

    func testWachheitBandIsShorterThanVertiefungBand() {
        let wachheit = CheckInIntervalPolicy(mode: .wachheit)
        let vertiefung = CheckInIntervalPolicy(mode: .vertiefung)
        XCTAssertLessThan(wachheit.mode.baseIntervalRange.upperBound, vertiefung.mode.baseIntervalRange.lowerBound)
    }
}
