import XCTest
import SwiftData
@testable import Rhythm

/// Exercises the pieces that touch SwiftData: cadence scheduling, streaks, and
/// the mutators the widgets and notification actions share.
@MainActor
final class StoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try RhythmStore.inMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func makeRitual(
        _ name: String = "Move",
        domain: Domain = .body,
        cadence: Cadence = .daily,
        targetPerWeek: Int = 3
    ) -> Ritual {
        let ritual = Ritual(
            name: name,
            domain: domain,
            cadence: cadence,
            targetPerWeek: targetPerWeek,
            anchor: Date().startOfDay.settingTime(minutesFromMidnight: 7 * 60)
        )
        context.insert(ritual)
        return ritual
    }

    @discardableResult
    private func complete(_ ritual: Ritual, on day: Date, isSkip: Bool = false) -> RitualEntry {
        let entry = RitualEntry(day: day, isSkip: isSkip, ritual: ritual)
        context.insert(entry)
        try? context.save()
        return entry
    }

    // MARK: - Cadence

    func testWeekdayRitualIsNotScheduledOnWeekends() {
        let ritual = makeRitual(cadence: .weekdays)
        let saturday = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(weekday: 7),
            matchingPolicy: .nextTime
        )!
        XCTAssertFalse(ritual.isScheduled(on: saturday))
    }

    func testWeeklyTargetFollowsCadence() {
        XCTAssertEqual(makeRitual(cadence: .daily).weeklyTarget, 7)
        XCTAssertEqual(makeRitual(cadence: .weekdays).weeklyTarget, 5)
        XCTAssertEqual(makeRitual(cadence: .weekends).weeklyTarget, 2)
        XCTAssertEqual(makeRitual(cadence: .timesPerWeek, targetPerWeek: 4).weeklyTarget, 4)
    }

    func testTimesPerWeekTargetIsClampedToARealWeek() {
        XCTAssertEqual(makeRitual(cadence: .timesPerWeek, targetPerWeek: 99).weeklyTarget, 7)
        XCTAssertEqual(makeRitual(cadence: .timesPerWeek, targetPerWeek: 0).weeklyTarget, 1)
    }

    /// A `.timesPerWeek` ritual should drop off today's list once the week's
    /// target is met, rather than nagging for an eighth session.
    func testTimesPerWeekDisappearsOnceTheTargetIsMet() {
        let ritual = makeRitual(cadence: .timesPerWeek, targetPerWeek: 2)
        let week = Calendar.current.daysOfWeek(containing: Date())
        let today = Date().startOfDay
        let others = week.filter { $0 != today }.prefix(2)
        for day in others { complete(ritual, on: day) }

        let due = DayQueries.ritualsDue(on: today, context: context)
        XCTAssertFalse(due.contains { $0.id == ritual.id })
    }

    // MARK: - Streaks

    func testStreakCountsConsecutiveKeptDays() {
        let ritual = makeRitual()
        let today = Date().startOfDay
        for offset in 0...3 { complete(ritual, on: today.adding(days: -offset)) }
        XCTAssertEqual(StreakEngine.streak(for: ritual, today: today), 4)
    }

    /// An unkept ritual earlier today must not wipe out yesterday's streak —
    /// the day is not over yet.
    func testTodayBeingUnkeptDoesNotBreakTheStreak() {
        let ritual = makeRitual()
        let today = Date().startOfDay
        for offset in 1...3 { complete(ritual, on: today.adding(days: -offset)) }
        XCTAssertEqual(StreakEngine.streak(for: ritual, today: today), 3)
    }

    func testAMissedDayEndsTheStreak() {
        let ritual = makeRitual()
        let today = Date().startOfDay
        complete(ritual, on: today)
        complete(ritual, on: today.adding(days: -1))
        // Gap at -2.
        complete(ritual, on: today.adding(days: -3))
        XCTAssertEqual(StreakEngine.streak(for: ritual, today: today), 2)
    }

    func testASkipPausesRatherThanEndsTheStreak() {
        let ritual = makeRitual()
        let today = Date().startOfDay
        complete(ritual, on: today)
        complete(ritual, on: today.adding(days: -1), isSkip: true)
        complete(ritual, on: today.adding(days: -2))
        XCTAssertEqual(StreakEngine.streak(for: ritual, today: today), 2)
    }

    // MARK: - Queries

    func testPrioritiesAreScopedToTheirDay() {
        context.insert(Priority(title: "Today", tier: .keystone, domain: .business, day: Date()))
        context.insert(Priority(title: "Tomorrow", tier: .keystone, domain: .business, day: Date().adding(days: 1)))
        try? context.save()

        let today = DayQueries.priorities(on: Date(), context: context)
        XCTAssertEqual(today.count, 1)
        XCTAssertEqual(today.first?.title, "Today")
    }

    func testKeystoneLookupIgnoresOtherTiers() {
        context.insert(Priority(title: "Small", tier: .maintenance, domain: .business, day: Date()))
        context.insert(Priority(title: "The one", tier: .keystone, domain: .business, day: Date()))
        try? context.save()
        XCTAssertEqual(DayQueries.keystone(on: Date(), context: context)?.title, "The one")
    }

    func testRollingScoreSkipsUntrackedDays() {
        let today = Date().startOfDay
        context.insert(DayLog(day: today, balanceScore: 80))
        context.insert(DayLog(day: today.adding(days: -1), balanceScore: 60))
        // A day with no log at all must not be averaged in as a zero.
        try? context.save()
        XCTAssertEqual(DayAssembler.rollingScore(days: 7, context: context, today: today), 70)
    }

    func testRollingScoreIsNilWithNoHistory() {
        XCTAssertNil(DayAssembler.rollingScore(days: 7, context: context))
    }

    // MARK: - Assembly

    func testAssemblerAssumesAClearRunwayWithoutCalendarAccess() {
        let input = DayAssembler.input(for: Date(), context: context, agenda: nil)
        XCTAssertEqual(input.longestFreeBlockMinutes, 240)
        XCTAssertEqual(input.meetingMinutes, 0)
    }

    func testRecomputePersistsTheScore() {
        context.insert(Priority(title: "Ship it", tier: .keystone, domain: .business, day: Date()))
        try? context.save()

        let result = DayAssembler.recompute(day: Date(), context: context, agenda: nil)
        let log = DayQueries.dayLog(for: Date(), context: context)
        XCTAssertEqual(log?.balanceScore, result.score)
    }

    func testDriftUsesCompletedWorkOnly() {
        let today = Date().startOfDay
        let done = Priority(title: "Called Mum", tier: .maintenance, domain: .relationships, day: today)
        done.setDone(true)
        context.insert(done)
        context.insert(Priority(title: "Gym", tier: .maintenance, domain: .body, day: today))
        try? context.save()

        let drift = DayAssembler.drift(context: context, windowDays: 14, today: today)
        XCTAssertEqual(drift.staleness(.relationships), 0)
        XCTAssertEqual(drift.staleness(.body), 14)
    }
}
