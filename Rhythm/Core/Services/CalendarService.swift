import EventKit
import Foundation

/// Wraps EventKit. Read-only by design: Rhythm reviews your calendar and tells
/// you what to fix, it does not rewrite your meetings behind your back.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()

    private(set) var authorization: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var agendas: [DayAgenda] = []
    private(set) var isLoading = false
    private(set) var lastLoadError: String?

    /// The deployment target is iOS 17, where `.authorized` is the write-only
    /// case and `.fullAccess` is what reading events requires.
    var hasAccess: Bool { authorization == .fullAccess }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    /// Requests read access. Rhythm asks for full access rather than write-only
    /// because the whole feature is reading what is already on the calendar.
    @discardableResult
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorization = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            lastLoadError = error.localizedDescription
            authorization = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    func availableCalendars() -> [EKCalendar] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// Loads `days` days starting today and analyses each one.
    func refresh(days: Int = 7, preferences: AppPreferences = .shared) async {
        guard hasAccess else {
            agendas = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: max(1, days), to: start) else { return }

        let selected = preferences.enabledCalendarIDs
        let calendars: [EKCalendar]? = selected.isEmpty
            ? nil
            : store.calendars(for: .event).filter { selected.contains($0.calendarIdentifier) }

        let boundaries = DayBoundaries(preferences: preferences)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let raw = store.events(matching: predicate)

        var byDay: [Date: [AgendaEvent]] = [:]
        for event in raw {
            guard let mapped = Self.map(event) else { continue }
            let key = calendar.startOfDay(for: mapped.start)
            byDay[key, default: []].append(mapped)
        }

        var result: [DayAgenda] = []
        for offset in 0..<max(1, days) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let events = (byDay[day] ?? []).sorted { $0.start < $1.start }
            result.append(Self.analyse(day: day, events: events, boundaries: boundaries))
        }
        agendas = result
        lastLoadError = nil
    }

    var today: DayAgenda? { agendas.first { Calendar.current.isDateInToday($0.day) } }

    var allIssues: [CalendarIssue] {
        agendas.flatMap(\.issues).sorted {
            $0.kind.rank == $1.kind.rank ? $0.day < $1.day : $0.kind.rank < $1.kind.rank
        }
    }

    // MARK: - Mapping

    private nonisolated static func map(_ event: EKEvent) -> AgendaEvent? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        let identifier = event.eventIdentifier ?? "\(event.title ?? "event")-\(start.timeIntervalSince1970)"
        let needsResponse: Bool
        if let attendees = event.attendees,
           let me = attendees.first(where: { $0.isCurrentUser }) {
            needsResponse = me.participantStatus == .pending
        } else {
            needsResponse = false
        }
        return AgendaEvent(
            id: identifier,
            title: event.title ?? "Untitled",
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title ?? "Calendar",
            calendarColorHex: event.calendar?.cgColor.flatMap(Self.hexString(from:)),
            location: event.location,
            attendeeCount: event.attendees?.count ?? 0,
            needsResponse: needsResponse
        )
    }

    private nonisolated static func hexString(from color: CGColor) -> String? {
        guard let comps = color.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    // MARK: - Analysis

    /// Pure and `nonisolated`, so it can be unit tested without EventKit or the
    /// main actor.
    nonisolated static func analyse(day: Date, events: [AgendaEvent], boundaries: DayBoundaries) -> DayAgenda {
        let calendar = Calendar.current
        let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        let dayStart = calendar.startOfDay(for: day)
        let workStart = dayStart.settingTime(minutesFromMidnight: boundaries.startMinutes)
        let workEnd = dayStart.settingTime(minutesFromMidnight: boundaries.endMinutes)
        let isWeekend = calendar.isDateInWeekend(day)

        var issues: [CalendarIssue] = []

        // Unanswered invites.
        for event in timed where event.needsResponse {
            issues.append(CalendarIssue(
                id: "unanswered-\(event.id)",
                kind: .unanswered,
                day: dayStart,
                detail: "\(event.title) at \(event.start.timeLabel) is still waiting on your response.",
                eventIDs: [event.id]
            ))
        }

        // Overlaps.
        for (index, event) in timed.enumerated() {
            // `timed` is sorted by start, so an overlap is exactly
            // "the next event begins before this one ends".
            for other in timed[(index + 1)...] where other.start < event.end {
                issues.append(CalendarIssue(
                    id: "conflict-\(event.id)-\(other.id)",
                    kind: .conflict,
                    day: dayStart,
                    detail: "\(event.title) overlaps \(other.title) at \(other.start.timeLabel).",
                    eventIDs: [event.id, other.id]
                ))
            }
        }

        // Work spilling past the boundary the user set.
        var afterHours = 0
        for event in timed {
            let before = max(0, Int(workStart.timeIntervalSince(event.start) / 60))
            let after = max(0, Int(event.end.timeIntervalSince(workEnd) / 60))
            let spill = min(event.durationMinutes, before + after)
            afterHours += spill
        }
        if afterHours >= 30, !isWeekend {
            issues.append(CalendarIssue(
                id: "afterhours-\(dayStart.timeIntervalSince1970)",
                kind: .afterHours,
                day: dayStart,
                detail: "\(afterHours.durationLabel) sits outside \(workStart.timeLabel)–\(workEnd.timeLabel).",
                eventIDs: []
            ))
        }

        // Meeting load and the largest uninterrupted block left for real work.
        let meetingMinutes = timed.reduce(0) { $0 + $1.durationMinutes }
        let workdayMinutes = boundaries.lengthMinutes
        if !isWeekend, Double(meetingMinutes) > Double(workdayMinutes) * 0.7 {
            issues.append(CalendarIssue(
                id: "overloaded-\(dayStart.timeIntervalSince1970)",
                kind: .overloaded,
                day: dayStart,
                detail: "\(meetingMinutes.durationLabel) of meetings against a \(workdayMinutes.durationLabel) day.",
                eventIDs: []
            ))
        }

        let longestFree = longestFreeBlockMinutes(in: timed, from: workStart, to: workEnd)
        if !isWeekend, !timed.isEmpty, longestFree < 60 {
            issues.append(CalendarIssue(
                id: "nobreak-\(dayStart.timeIntervalSince1970)",
                kind: .noBreak,
                day: dayStart,
                detail: "Longest clear stretch is \(longestFree.durationLabel). Deep work needs a runway.",
                eventIDs: []
            ))
        }

        // A weekday with nothing on it usually means the calendar is out of date,
        // not that the day is free.
        if !isWeekend, timed.isEmpty, day > Date() {
            issues.append(CalendarIssue(
                id: "empty-\(dayStart.timeIntervalSince1970)",
                kind: .emptyDay,
                day: dayStart,
                detail: "A workday with nothing on it. Is this accurate?",
                eventIDs: []
            ))
        }

        // Something on the calendar that is not work.
        let hasPersonal = events.contains { event in
            let afterWork = event.start >= workEnd || event.end <= workStart
            return afterWork || isWeekend
        }
        if !hasPersonal, !isWeekend, !timed.isEmpty {
            issues.append(CalendarIssue(
                id: "nopersonal-\(dayStart.timeIntervalSince1970)",
                kind: .noPersonalTime,
                day: dayStart,
                detail: "Nothing on the calendar for you after \(workEnd.timeLabel).",
                eventIDs: []
            ))
        }

        var agenda = DayAgenda(day: dayStart, events: events, issues: issues)
        agenda.afterHoursMinutes = afterHours
        agenda.longestFreeBlockMinutes = longestFree
        return agenda
    }

    /// Largest gap between merged events inside the working window.
    nonisolated static func longestFreeBlockMinutes(in events: [AgendaEvent], from start: Date, to end: Date) -> Int {
        guard end > start else { return 0 }
        let window = events
            .map { (max($0.start, start), min($0.end, end)) }
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }

        var merged: [(Date, Date)] = []
        for slot in window {
            if let last = merged.last, slot.0 <= last.1 {
                merged[merged.count - 1].1 = max(last.1, slot.1)
            } else {
                merged.append(slot)
            }
        }

        var cursor = start
        var longest = 0
        for slot in merged {
            longest = max(longest, Int(slot.0.timeIntervalSince(cursor) / 60))
            cursor = max(cursor, slot.1)
        }
        longest = max(longest, Int(end.timeIntervalSince(cursor) / 60))
        return max(0, longest)
    }
}
