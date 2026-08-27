import XCTest
@testable import Rhythm

final class CalendarAnalysisTests: XCTestCase {

    private let boundaries = DayBoundaries(startMinutes: 9 * 60, endMinutes: 17 * 60)

    /// A fixed Tuesday, so weekend behaviour never depends on when the suite runs.
    private var tuesday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 10
        components.hour = 0
        return Calendar.current.date(from: components)!.startOfDay
    }

    private var saturday: Date { tuesday.adding(days: 4) }

    private func event(
        _ title: String,
        day: Date,
        fromMinutes: Int,
        durationMinutes: Int,
        needsResponse: Bool = false,
        isAllDay: Bool = false
    ) -> AgendaEvent {
        let start = day.settingTime(minutesFromMidnight: fromMinutes)
        return AgendaEvent(
            id: "\(title)-\(fromMinutes)",
            title: title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            isAllDay: isAllDay,
            calendarTitle: "Work",
            calendarColorHex: nil,
            location: nil,
            attendeeCount: 3,
            needsResponse: needsResponse
        )
    }

    private func kinds(_ agenda: DayAgenda) -> Set<CalendarIssue.Kind> {
        Set(agenda.issues.map(\.kind))
    }

    // MARK: - Free blocks

    func testLongestFreeBlockSpansTheGapBetweenMeetings() {
        let day = tuesday
        let events = [
            event("Standup", day: day, fromMinutes: 9 * 60, durationMinutes: 30),
            event("Review", day: day, fromMinutes: 15 * 60, durationMinutes: 60)
        ]
        let free = CalendarService.longestFreeBlockMinutes(
            in: events,
            from: day.settingTime(minutesFromMidnight: 9 * 60),
            to: day.settingTime(minutesFromMidnight: 17 * 60)
        )
        // 09:30 to 15:00 is the biggest gap.
        XCTAssertEqual(free, 330)
    }

    func testOverlappingEventsAreMergedBeforeMeasuringGaps() {
        let day = tuesday
        let events = [
            event("A", day: day, fromMinutes: 9 * 60, durationMinutes: 180),
            event("B", day: day, fromMinutes: 10 * 60, durationMinutes: 60)
        ]
        let free = CalendarService.longestFreeBlockMinutes(
            in: events,
            from: day.settingTime(minutesFromMidnight: 9 * 60),
            to: day.settingTime(minutesFromMidnight: 17 * 60)
        )
        // The nested meeting must not create a phantom gap: 12:00–17:00.
        XCTAssertEqual(free, 300)
    }

    func testFullyBookedDayHasNoFreeBlock() {
        let day = tuesday
        let events = [event("All day sync", day: day, fromMinutes: 9 * 60, durationMinutes: 480)]
        let free = CalendarService.longestFreeBlockMinutes(
            in: events,
            from: day.settingTime(minutesFromMidnight: 9 * 60),
            to: day.settingTime(minutesFromMidnight: 17 * 60)
        )
        XCTAssertEqual(free, 0)
    }

    // MARK: - Issues

    func testOverlapIsFlaggedAsAConflict() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Board call", day: day, fromMinutes: 10 * 60, durationMinutes: 60),
            event("1:1", day: day, fromMinutes: 10 * 60 + 30, durationMinutes: 30)
        ], boundaries: boundaries)
        XCTAssertTrue(kinds(agenda).contains(.conflict))
    }

    func testBackToBackMeetingsAreNotAConflict() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("First", day: day, fromMinutes: 10 * 60, durationMinutes: 60),
            event("Second", day: day, fromMinutes: 11 * 60, durationMinutes: 60)
        ], boundaries: boundaries)
        XCTAssertFalse(kinds(agenda).contains(.conflict))
    }

    func testUnansweredInviteIsFlagged() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Offsite", day: day, fromMinutes: 14 * 60, durationMinutes: 60, needsResponse: true)
        ], boundaries: boundaries)
        XCTAssertTrue(kinds(agenda).contains(.unanswered))
    }

    func testWorkPastTheHardStopIsCountedAsAfterHours() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Late call", day: day, fromMinutes: 16 * 60, durationMinutes: 180)
        ], boundaries: boundaries)
        // 17:00–19:00 lies outside the window.
        XCTAssertEqual(agenda.afterHoursMinutes, 120)
        XCTAssertTrue(kinds(agenda).contains(.afterHours))
    }

    func testEarlyMeetingBeforeTheWorkdayCountsToo() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Europe sync", day: day, fromMinutes: 7 * 60, durationMinutes: 120)
        ], boundaries: boundaries)
        XCTAssertEqual(agenda.afterHoursMinutes, 120)
    }

    func testOverloadedDayIsFlaggedAboveSeventyPercentBooked() {
        let day = tuesday
        // 6 hours against an 8-hour day is 75%.
        let agenda = CalendarService.analyse(day: day, events: [
            event("Marathon", day: day, fromMinutes: 9 * 60, durationMinutes: 360)
        ], boundaries: boundaries)
        XCTAssertTrue(kinds(agenda).contains(.overloaded))
    }

    func testEmptyFutureWorkdayIsFlagged() throws {
        let future = Date().adding(days: 3).startOfDay
        guard !Calendar.current.isDateInWeekend(future) else {
            throw XCTSkip("Chosen day landed on a weekend")
        }
        let agenda = CalendarService.analyse(day: future, events: [], boundaries: boundaries)
        XCTAssertTrue(kinds(agenda).contains(.emptyDay))
    }

    func testWeekendIsNotJudgedByWorkdayRules() {
        let day = saturday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Long lunch", day: day, fromMinutes: 12 * 60, durationMinutes: 180)
        ], boundaries: boundaries)
        let flagged = kinds(agenda)
        XCTAssertFalse(flagged.contains(.afterHours))
        XCTAssertFalse(flagged.contains(.overloaded))
        XCTAssertFalse(flagged.contains(.noBreak))
        XCTAssertFalse(flagged.contains(.emptyDay))
        XCTAssertFalse(flagged.contains(.noPersonalTime))
    }

    func testDayWithSomethingAfterHoursIsNotFlaggedForNoPersonalTime() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Standup", day: day, fromMinutes: 9 * 60, durationMinutes: 30),
            event("Dinner with Sam", day: day, fromMinutes: 19 * 60, durationMinutes: 90)
        ], boundaries: boundaries)
        XCTAssertFalse(kinds(agenda).contains(.noPersonalTime))
    }

    func testBoundariesCannotInvert() {
        let boundaries = DayBoundaries(startMinutes: 18 * 60, endMinutes: 8 * 60)
        XCTAssertGreaterThanOrEqual(boundaries.lengthMinutes, 60)
    }

    func testMeetingMinutesExcludeAllDayEvents() {
        let day = tuesday
        let agenda = CalendarService.analyse(day: day, events: [
            event("Conference", day: day, fromMinutes: 0, durationMinutes: 1440, isAllDay: true),
            event("Standup", day: day, fromMinutes: 9 * 60, durationMinutes: 30)
        ], boundaries: boundaries)
        XCTAssertEqual(agenda.meetingMinutes, 30)
    }
}
