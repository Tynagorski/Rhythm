import Foundation

/// A calendar event flattened into a value type. EventKit objects are not safe
/// to hold across contexts, and the widget never touches EventKit at all, so
/// everything downstream works on these instead.
struct AgendaEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColorHex: String?
    let location: String?
    let attendeeCount: Int
    /// The user has been invited but has not answered. These are the events that
    /// quietly rot a calendar.
    let needsResponse: Bool

    var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

/// One thing wrong with the upcoming week, ranked so the review flow can lead
/// with what actually matters.
struct CalendarIssue: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case unanswered
        case conflict
        case afterHours
        case noBreak
        case overloaded
        case emptyDay
        case noPersonalTime

        var title: String {
            switch self {
            case .unanswered: "Unanswered invite"
            case .conflict: "Double booked"
            case .afterHours: "Outside your hours"
            case .noBreak: "No break"
            case .overloaded: "Overloaded day"
            case .emptyDay: "Nothing scheduled"
            case .noPersonalTime: "No personal time"
            }
        }

        var symbol: String {
            switch self {
            case .unanswered: "questionmark.circle.fill"
            case .conflict: "square.on.square.dashed"
            case .afterHours: "moon.fill"
            case .noBreak: "timer"
            case .overloaded: "chart.bar.fill"
            case .emptyDay: "calendar.badge.exclamationmark"
            case .noPersonalTime: "heart.slash.fill"
            }
        }

        /// Lower sorts first.
        var rank: Int {
            switch self {
            case .conflict: 0
            case .unanswered: 1
            case .overloaded: 2
            case .afterHours: 3
            case .noBreak: 4
            case .noPersonalTime: 5
            case .emptyDay: 6
            }
        }

        var isSevere: Bool {
            switch self {
            case .conflict, .unanswered, .overloaded: true
            default: false
            }
        }
    }

    let id: String
    let kind: Kind
    let day: Date
    let detail: String
    let eventIDs: [String]
}

/// The user's working window, extracted from preferences so calendar analysis
/// stays a pure function over `Sendable` values.
struct DayBoundaries: Hashable, Sendable {
    var startMinutes: Int
    var endMinutes: Int

    init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = startMinutes
        // A window that ends before it starts would make every gap negative.
        self.endMinutes = max(startMinutes + 60, endMinutes)
    }

    init(preferences: AppPreferences) {
        self.init(startMinutes: preferences.workdayStartMinutes, endMinutes: preferences.workdayEndMinutes)
    }

    var lengthMinutes: Int { endMinutes - startMinutes }
}

/// A day's worth of calendar, plus the load numbers the balance engine needs.
struct DayAgenda: Identifiable, Hashable, Sendable {
    let day: Date
    var events: [AgendaEvent]
    var issues: [CalendarIssue]

    var id: Date { day }

    var meetingMinutes: Int {
        events.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
    }

    var afterHoursMinutes: Int = 0
    var longestFreeBlockMinutes: Int = 0
}
