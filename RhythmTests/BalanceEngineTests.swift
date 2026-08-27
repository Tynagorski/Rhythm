import XCTest
@testable import Rhythm

final class BalanceEngineTests: XCTestCase {

    private func input(
        priorities: [(PriorityTier, Domain, Bool)] = [],
        rituals: [(Domain, Bool, Bool)] = [],
        meetingMinutes: Int = 0,
        afterHoursMinutes: Int = 0,
        longestFreeBlockMinutes: Int = 240,
        isWeekend: Bool = false,
        didShutDown: Bool = false
    ) -> BalanceInput {
        var input = BalanceInput()
        input.priorities = priorities.map { .init(tier: $0.0, domain: $0.1, isDone: $0.2) }
        input.rituals = rituals.map { .init(domain: $0.0, isDone: $0.1, isSkip: $0.2) }
        input.meetingMinutes = meetingMinutes
        input.afterHoursMinutes = afterHoursMinutes
        input.longestFreeBlockMinutes = longestFreeBlockMinutes
        input.boundaries = DayBoundaries(startMinutes: 8 * 60, endMinutes: 18 * 60)
        input.isWeekend = isWeekend
        input.didShutDown = didShutDown
        return input
    }

    // MARK: - Execution

    func testExecutionIsWeightedByTier() {
        // Keystone done, both momentum tasks missed: 3 of 6 weighted points.
        let result = BalanceEngine.executionRatio(input(priorities: [
            (.keystone, .business, true),
            (.momentum, .business, false),
            (.momentum, .business, false)
        ]))
        XCTAssertEqual(try XCTUnwrap(result), 0.5, accuracy: 0.001)
    }

    func testExecutionIsNilWhenNothingPlanned() {
        XCTAssertNil(BalanceEngine.executionRatio(input()))
    }

    /// A day where nothing was planned must not be scored as a total failure —
    /// the missing component is dropped, not zeroed.
    func testUnplannedDayDoesNotScoreZeroExecution() {
        let planned = BalanceEngine.evaluate(input(
            priorities: [(.keystone, .business, false)],
            rituals: [(.body, true, false)]
        ))
        let unplanned = BalanceEngine.evaluate(input(rituals: [(.body, true, false)]))
        XCTAssertGreaterThan(unplanned.score, planned.score)
    }

    // MARK: - Rituals

    func testDeliberateSkipsShrinkTheDenominator() {
        // One kept, one skipped: 100%, not 50%.
        let ratio = BalanceEngine.ritualRatio(input(rituals: [
            (.body, true, false),
            (.mind, false, true)
        ]))
        XCTAssertEqual(try XCTUnwrap(ratio), 1.0, accuracy: 0.001)
    }

    func testAllSkippedLeavesRitualsUnscored() {
        XCTAssertNil(BalanceEngine.ritualRatio(input(rituals: [(.body, false, true)])))
    }

    // MARK: - Coverage

    func testCoverageCountsOnlyCompletedWork() {
        let covered = BalanceEngine.coveredDomains(input(
            priorities: [(.keystone, .business, true), (.momentum, .mind, false)],
            rituals: [(.body, true, false), (.recovery, false, false)]
        ))
        XCTAssertEqual(covered, [.business, .body])
    }

    /// The core product claim: an all-business day cannot score like a balanced
    /// one, however much got done.
    func testAllBusinessDayScoresBelowBalancedDay() {
        let grind = BalanceEngine.evaluate(input(
            priorities: [
                (.keystone, .business, true),
                (.momentum, .business, true),
                (.momentum, .business, true)
            ],
            rituals: [(.business, true, false)]
        ))
        let balanced = BalanceEngine.evaluate(input(
            priorities: [
                (.keystone, .business, true),
                (.momentum, .relationships, true),
                (.momentum, .mind, true)
            ],
            rituals: [(.body, true, false), (.recovery, true, false)]
        ))
        XCTAssertLessThan(grind.score, balanced.score)
    }

    // MARK: - Protection

    func testAfterHoursWorkErodesProtection() {
        let clean = BalanceEngine.protectionRatio(input(meetingMinutes: 120))
        let spilled = BalanceEngine.protectionRatio(input(meetingMinutes: 120, afterHoursMinutes: 120))
        XCTAssertEqual(clean, 1.0, accuracy: 0.001)
        XCTAssertLessThan(spilled, 0.6)
    }

    func testMeetingSaturationBelowSixtyPercentIsFree() {
        // 5 hours of a 10-hour day is 50% — under the threshold.
        XCTAssertEqual(BalanceEngine.protectionRatio(input(meetingMinutes: 300)), 1.0, accuracy: 0.001)
    }

    func testFragmentedDayLosesProtectionEvenWithLightLoad() {
        let fragmented = BalanceEngine.protectionRatio(input(meetingMinutes: 120, longestFreeBlockMinutes: 20))
        XCTAssertLessThan(fragmented, 1.0)
    }

    func testWeekendIgnoresSaturationAndFragmentation() {
        let weekend = BalanceEngine.protectionRatio(
            input(meetingMinutes: 0, longestFreeBlockMinutes: 0, isWeekend: true)
        )
        XCTAssertEqual(weekend, 1.0, accuracy: 0.001)
    }

    func testWeekendStillPenalisesWorkThatSpilledIntoIt() {
        let working = BalanceEngine.protectionRatio(input(meetingMinutes: 240, isWeekend: true))
        XCTAssertEqual(working, 0.0, accuracy: 0.001)
    }

    // MARK: - Score

    func testScoreIsClampedToPercent() {
        let perfect = BalanceEngine.evaluate(input(
            priorities: Domain.allCases.map { (.momentum, $0, true) },
            rituals: Domain.allCases.map { ($0, true, false) },
            didShutDown: true
        ))
        XCTAssertLessThanOrEqual(perfect.score, 100)
        XCTAssertGreaterThan(perfect.score, 90)
    }

    func testShutdownAddsASmallBonus() {
        let base = input(priorities: [(.keystone, .business, true)], rituals: [(.body, true, false)])
        var closed = base
        closed.didShutDown = true
        XCTAssertGreaterThan(BalanceEngine.evaluate(closed).score, BalanceEngine.evaluate(base).score)
    }

    func testEmptyDayHasAPromptRatherThanAVerdict() {
        XCTAssertTrue(BalanceEngine.evaluate(input()).headline.contains("keystone"))
    }

    // MARK: - Drift

    func testDriftReportsDaysSinceLastTouch() {
        let today = Date().startOfDay
        let report = BalanceEngine.drift(
            touches: [.business: [today], .body: [today.adding(days: -4)]],
            today: today,
            windowDays: 14
        )
        XCTAssertEqual(report.staleness(.business), 0)
        XCTAssertEqual(report.staleness(.body), 4)
        // Never touched inside the window falls back to the window length.
        XCTAssertEqual(report.staleness(.mind), 14)
    }

    func testStarvedDomainsAreOrderedWorstFirst() {
        let today = Date().startOfDay
        let report = BalanceEngine.drift(
            touches: [
                .business: [today],
                .body: [today.adding(days: -3)],
                .mind: [today.adding(days: -6)],
                .relationships: [today.adding(days: -1)],
                .recovery: [today.adding(days: -9)]
            ],
            today: today,
            windowDays: 14
        )
        XCTAssertEqual(report.worst, .recovery)
        XCTAssertEqual(report.starved, [.recovery, .mind, .body])
    }
}
