import Foundation
import UserNotifications

/// Every notification Rhythm can send, with a stable identifier so rescheduling
/// replaces rather than duplicates.
enum RhythmNotification {
    static let morningBrief = "rhythm.morningBrief"
    static let middayCheck = "rhythm.middayCheck"
    static let shutdown = "rhythm.shutdown"
    static let weeklyReset = "rhythm.weeklyReset"
    static let driftAlert = "rhythm.driftAlert"

    /// The calendar nudge escalates over several days, so each step gets its own
    /// identifier and they are all cleared together when a review lands.
    static func calendarNudge(step: Int) -> String { "rhythm.calendarNudge.\(step)" }
    static func ritual(_ id: UUID) -> String { "rhythm.ritual.\(id.uuidString)" }

    enum Category {
        static let calendarReview = "RHYTHM_CALENDAR_REVIEW"
        static let ritual = "RHYTHM_RITUAL"
        static let shutdown = "RHYTHM_SHUTDOWN"
        static let brief = "RHYTHM_BRIEF"
    }

    enum Action {
        static let reviewNow = "RHYTHM_REVIEW_NOW"
        static let remindTomorrow = "RHYTHM_REMIND_TOMORROW"
        static let completeRitual = "RHYTHM_COMPLETE_RITUAL"
        static let skipRitual = "RHYTHM_SKIP_RITUAL"
        static let startShutdown = "RHYTHM_START_SHUTDOWN"
        static let openPlan = "RHYTHM_OPEN_PLAN"
    }

    enum UserInfoKey {
        static let route = "route"
        static let ritualID = "ritualID"
    }
}

/// Where a notification should land when tapped. Kept as a small enum so both
/// local and remote notifications route through one path.
enum RhythmRoute: String, Hashable {
    case today
    case plan
    case rituals
    case balance
    case calendarReview
    case shutdown
    case settings

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo[RhythmNotification.UserInfoKey.route] as? String else { return nil }
        self.init(rawValue: raw)
    }
}

/// The slice of a `Ritual` the notification scheduler needs. Passing a value
/// type keeps SwiftData models off the notification code path.
struct RitualReminder: Sendable {
    var id: UUID
    var name: String
    var detail: String
    var domain: Domain
    var anchor: DateComponents
    var remindersEnabled: Bool
}


/// Widgets deep-link with `rhythm://` URLs; notifications carry a `RhythmRoute`
/// directly. Both end up in the same place.
enum DeepLink {
    static let scheme = "rhythm"

    static func url(for route: RhythmRoute) -> URL {
        URL(string: "\(scheme)://\(route.rawValue)") ?? URL(string: "\(scheme)://today")!
    }

    static func route(from url: URL) -> RhythmRoute? {
        guard url.scheme == scheme else { return nil }
        let raw = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return RhythmRoute(rawValue: raw)
    }
}

/// Cancelling the escalating calendar nudges has to work from the widget
/// extension too, where `UIApplication` — and therefore `NotificationService` —
/// is unavailable. `UNUserNotificationCenter` is extension-safe, so the cancel
/// path lives here on its own.
enum NotificationCleanup {
    static func clearCalendarNudges() {
        let ids = (0..<3).map(RhythmNotification.calendarNudge(step:))
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
