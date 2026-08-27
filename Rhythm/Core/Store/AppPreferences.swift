import Foundation
import SwiftUI

/// User-facing settings. Everything lives in the App Group suite so widgets and
/// App Intents see the same values the app does.
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.workdayStartMinutes: 8 * 60,
            Key.workdayEndMinutes: 18 * 60,
            Key.morningBriefMinutes: 7 * 60,
            Key.middayCheckMinutes: 13 * 60,
            Key.calendarReviewIntervalDays: 3,
            Key.morningBriefEnabled: true,
            Key.middayCheckEnabled: true,
            Key.shutdownEnabled: true,
            Key.calendarNudgeEnabled: true,
            Key.driftAlertsEnabled: true,
            Key.ritualRemindersEnabled: true,
            Key.quietWeekends: false,
            Key.hasCompletedOnboarding: false,
            Key.hasSeededRituals: false
        ])
    }

    private enum Key {
        static let workdayStartMinutes = "workdayStartMinutes"
        static let workdayEndMinutes = "workdayEndMinutes"
        static let morningBriefMinutes = "morningBriefMinutes"
        static let middayCheckMinutes = "middayCheckMinutes"
        static let calendarReviewIntervalDays = "calendarReviewIntervalDays"
        static let morningBriefEnabled = "morningBriefEnabled"
        static let middayCheckEnabled = "middayCheckEnabled"
        static let shutdownEnabled = "shutdownEnabled"
        static let calendarNudgeEnabled = "calendarNudgeEnabled"
        static let driftAlertsEnabled = "driftAlertsEnabled"
        static let ritualRemindersEnabled = "ritualRemindersEnabled"
        static let quietWeekends = "quietWeekends"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSeededRituals = "hasSeededRituals"
        static let lastCalendarReview = "lastCalendarReview"
        static let pushToken = "pushToken"
        static let calendarIDs = "enabledCalendarIDs"
    }

    // MARK: - Boundaries

    /// Minutes from midnight. Stored as Int rather than Date so the boundary
    /// means the same thing across time zones — a 6pm hard stop is 6pm wherever
    /// you land.
    var workdayStartMinutes: Int {
        get { access { defaults.integer(forKey: Key.workdayStartMinutes) } }
        set { mutate { defaults.set(newValue, forKey: Key.workdayStartMinutes) } }
    }

    var workdayEndMinutes: Int {
        get { access { defaults.integer(forKey: Key.workdayEndMinutes) } }
        set { mutate { defaults.set(newValue, forKey: Key.workdayEndMinutes) } }
    }

    var morningBriefMinutes: Int {
        get { access { defaults.integer(forKey: Key.morningBriefMinutes) } }
        set { mutate { defaults.set(newValue, forKey: Key.morningBriefMinutes) } }
    }

    var middayCheckMinutes: Int {
        get { access { defaults.integer(forKey: Key.middayCheckMinutes) } }
        set { mutate { defaults.set(newValue, forKey: Key.middayCheckMinutes) } }
    }

    /// How many days may pass before Rhythm insists on a calendar review.
    var calendarReviewIntervalDays: Int {
        get { access { max(1, defaults.integer(forKey: Key.calendarReviewIntervalDays)) } }
        set { mutate { defaults.set(max(1, newValue), forKey: Key.calendarReviewIntervalDays) } }
    }

    // MARK: - Notification toggles

    var morningBriefEnabled: Bool {
        get { access { defaults.bool(forKey: Key.morningBriefEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.morningBriefEnabled) } }
    }

    var middayCheckEnabled: Bool {
        get { access { defaults.bool(forKey: Key.middayCheckEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.middayCheckEnabled) } }
    }

    var shutdownEnabled: Bool {
        get { access { defaults.bool(forKey: Key.shutdownEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.shutdownEnabled) } }
    }

    var calendarNudgeEnabled: Bool {
        get { access { defaults.bool(forKey: Key.calendarNudgeEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.calendarNudgeEnabled) } }
    }

    var driftAlertsEnabled: Bool {
        get { access { defaults.bool(forKey: Key.driftAlertsEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.driftAlertsEnabled) } }
    }

    var ritualRemindersEnabled: Bool {
        get { access { defaults.bool(forKey: Key.ritualRemindersEnabled) } }
        set { mutate { defaults.set(newValue, forKey: Key.ritualRemindersEnabled) } }
    }

    /// Suppresses work-shaped nudges on Saturday and Sunday.
    var quietWeekends: Bool {
        get { access { defaults.bool(forKey: Key.quietWeekends) } }
        set { mutate { defaults.set(newValue, forKey: Key.quietWeekends) } }
    }

    // MARK: - State

    var hasCompletedOnboarding: Bool {
        get { access { defaults.bool(forKey: Key.hasCompletedOnboarding) } }
        set { mutate { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) } }
    }

    var hasSeededRituals: Bool {
        get { access { defaults.bool(forKey: Key.hasSeededRituals) } }
        set { mutate { defaults.set(newValue, forKey: Key.hasSeededRituals) } }
    }

    /// Mirrored out of SwiftData so widgets can show calendar staleness without
    /// opening the model container.
    var lastCalendarReview: Date? {
        get {
            access {
                let t = defaults.double(forKey: Key.lastCalendarReview)
                return t > 0 ? Date(timeIntervalSince1970: t) : nil
            }
        }
        set {
            mutate {
                defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.lastCalendarReview)
            }
        }
    }

    var pushToken: String? {
        get { access { defaults.string(forKey: Key.pushToken) } }
        set { mutate { defaults.set(newValue, forKey: Key.pushToken) } }
    }

    /// Calendar identifiers the user opted into. Empty means "all calendars".
    var enabledCalendarIDs: [String] {
        get { access { defaults.stringArray(forKey: Key.calendarIDs) ?? [] } }
        set { mutate { defaults.set(newValue, forKey: Key.calendarIDs) } }
    }

    // MARK: - Derived

    var workdayStart: DateComponents { Self.components(fromMinutes: workdayStartMinutes) }
    var workdayEnd: DateComponents { Self.components(fromMinutes: workdayEndMinutes) }
    var morningBrief: DateComponents { Self.components(fromMinutes: morningBriefMinutes) }
    var middayCheck: DateComponents { Self.components(fromMinutes: middayCheckMinutes) }

    static func components(fromMinutes minutes: Int) -> DateComponents {
        DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Days since the last calendar review, or `nil` if one has never happened.
    var daysSinceCalendarReview: Int? {
        guard let last = lastCalendarReview else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day
    }

    var calendarIsStale: Bool {
        guard let days = daysSinceCalendarReview else { return true }
        return days >= calendarReviewIntervalDays
    }

    // MARK: - Observation plumbing

    /// `@Observable` cannot see through `UserDefaults`, so every read and write
    /// is funnelled through these. Tracking is intentionally coarse — one token
    /// for the whole settings object — because settings change rarely and a
    /// per-key registrar would buy nothing but bookkeeping.
    @ObservationIgnored private let registrar = ObservationRegistrar()
    @ObservationIgnored private var revision: Int = 0

    private func access<T>(_ body: () -> T) -> T {
        registrar.access(self, keyPath: \AppPreferences.revision)
        return body()
    }

    private func mutate(_ body: () -> Void) {
        registrar.withMutation(of: self, keyPath: \AppPreferences.revision) {
            revision &+= 1
            body()
        }
    }
}
