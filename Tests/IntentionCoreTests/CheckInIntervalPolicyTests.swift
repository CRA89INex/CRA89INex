import XCTest
@testable import IntentionCore

final class CheckInIntervalPolicyTests: XCTestCase {
    private let defaultRange: ClosedRange<TimeInterval> = 6 * 60...12 * 60

    func testInitialDriftFactorIsNeutral() {
        let policy = CheckInIntervalPolicy(baseRange: defaultRange)
        XCTAssertEqual(policy.driftFactor, 1.0)
    }

    func testTwoConsecutiveYesAnswersDampenTheCadence() {
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
        policy.recordAnswer(.yes)
        XCTAssertEqual(policy.driftFactor, 1.0, "a single yes should not change anything yet")

        policy.recordAnswer(.yes)
        XCTAssertGreaterThan(policy.driftFactor, 1.0, "two yeses in a row should lengthen the interval")
    }

    func testNoCompressesTheCadence() {
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
        policy.recordAnswer(.yes)
        policy.recordAnswer(.yes)
        let dampened = policy.driftFactor

        policy.recordAnswer(.no)

        XCTAssertLessThan(policy.driftFactor, dampened)
        XCTAssertLessThan(policy.driftFactor, 1.0)
    }

    func testMissedDetourReturnAlsoCompressesTheCadence() {
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
        policy.recordMissedDetourReturn()
        XCTAssertLessThan(policy.driftFactor, 1.0)
    }

    func testDriftFactorIsClamped() {
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
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
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
        policy.recordAnswer(.yes)
        policy.recordAnswer(.unanswered)
        policy.recordAnswer(.yes)
        // The streak was reset, so this single yes shouldn't have dampened yet.
        XCTAssertEqual(policy.driftFactor, 1.0)
    }

    func testNextIntervalUsesBaseRangeAndDriftFactor() {
        var policy = CheckInIntervalPolicy(baseRange: defaultRange)
        policy.recordAnswer(.no) // driftFactor 0.6

        let interval = policy.nextInterval(sample: { _ in 10 * 60 })

        XCTAssertEqual(interval, 10 * 60 * 0.6, accuracy: 0.001)
    }

    // MARK: aroundChosenPace (Anker's user-adjustable interval)

    func testAroundChosenPaceCentersOnTheChosenMinutes() {
        let range = CheckInIntervalPolicy.aroundChosenPace(6)
        XCTAssertEqual(range.lowerBound, 4 * 60, accuracy: 0.001)
        XCTAssertEqual(range.upperBound, 8 * 60, accuracy: 0.001)
    }

    func testAroundChosenPaceClampsToTheAllowedThreeToTwelveMinuteRange() {
        let low = CheckInIntervalPolicy.aroundChosenPace(1) // below the 3 min floor
        XCTAssertEqual(low.lowerBound, 3 * 60, accuracy: 0.001)

        let high = CheckInIntervalPolicy.aroundChosenPace(30) // above the 12 min ceiling
        XCTAssertEqual(high.upperBound, 12 * 60, accuracy: 0.001)
    }

    func testAroundChosenPaceNeverExceedsTheAllowedBounds() {
        for minutes in stride(from: TimeInterval(0), through: 20, by: 1) {
            let range = CheckInIntervalPolicy.aroundChosenPace(minutes)
            XCTAssertGreaterThanOrEqual(range.lowerBound, 3 * 60)
            XCTAssertLessThanOrEqual(range.upperBound, 12 * 60)
        }
    }
}
