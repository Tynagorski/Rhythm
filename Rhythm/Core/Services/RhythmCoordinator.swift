import Foundation
import SwiftData
import SwiftUI

/// The one place that knows the order things have to happen in: read the
/// calendar, score the day, re-derive drift, rebuild the notification schedule,
/// refresh widgets. Views ask for a refresh; they never orchestrate it.
@MainActor
@Observable
final class RhythmCoordinator {
    static let shared = RhythmCoordinator()

    private(set) var todayResult: BalanceResult = .empty
    private(set) var rollingScore: Int?
    private(set) var drift: DriftReport = DriftReport(daysSinceTouched: [:], windowDays: 14)
    private(set) var shutdownStreak: Int = 0
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    /// Set by the app on launch. Held weakly-ish as an implicitly unwrapped
    /// container reference because the coordinator is useless before it exists.
    private var container: ModelContainer?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext? {
        container.map { ModelContext($0) }
    }

    // MARK: - Refresh

    /// Full pass. Safe to call on launch, on foreground, and after any mutation.
    func refreshEverything(preferences: AppPreferences = .shared) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let calendar = CalendarService.shared
        if calendar.hasAccess {
            await calendar.refresh(days: 7, preferences: preferences)
        }

        guard let context else { return }

        let agenda = calendar.today
        todayResult = DayAssembler.recompute(day: Date(), context: context, agenda: agenda, preferences: preferences)
        rollingScore = DayAssembler.rollingScore(days: 7, context: context)
        drift = DayAssembler.drift(context: context)
        shutdownStreak = StreakEngine.shutdownStreak(context: context)

        // Yesterday's score is only final once the day is over; recompute it
        // once so an evening of late completions is reflected in the trend.
        let yesterday = Date().adding(days: -1)
        if DayQueries.dayLog(for: yesterday, context: context) != nil {
            DayAssembler.recompute(day: yesterday, context: context, agenda: nil, preferences: preferences)
        }

        await rescheduleNotifications(preferences: preferences)
        WidgetRefresher.reloadAll()
        lastRefresh = Date()
    }

    /// Cheaper path used after a single toggle: rescore today and refresh
    /// widgets without re-reading EventKit.
    func refreshScoreOnly(preferences: AppPreferences = .shared) {
        guard let context else { return }
        todayResult = DayAssembler.recompute(
            day: Date(),
            context: context,
            agenda: CalendarService.shared.today,
            preferences: preferences
        )
        rollingScore = DayAssembler.rollingScore(days: 7, context: context)
        drift = DayAssembler.drift(context: context)
        WidgetRefresher.reloadAll()
    }

    func rescheduleNotifications(preferences: AppPreferences = .shared) async {
        guard let context else { return }
        let reminders = DayQueries.activeRituals(context: context).map { ritual in
            RitualReminder(
                id: ritual.id,
                name: ritual.name,
                detail: ritual.detail,
                domain: ritual.domain,
                anchor: ritual.anchorComponents(),
                remindersEnabled: ritual.remindersEnabled
            )
        }
        await NotificationService.shared.rescheduleAll(
            preferences: preferences,
            rituals: reminders,
            drift: drift
        )
        NotificationService.shared.setBadge(badgeCount(preferences: preferences))
    }

    /// The badge answers one question: is there something today that Rhythm
    /// needs from you? Overdue calendar review plus unfinished keystone.
    private func badgeCount(preferences: AppPreferences) -> Int {
        var count = 0
        if preferences.calendarIsStale { count += 1 }
        if let context, let keystone = DayQueries.keystone(on: Date(), context: context), !keystone.isDone {
            count += 1
        }
        return count
    }

    // MARK: - Calendar review

    /// Records a completed review, stops the escalating nudges, and resets the
    /// staleness clock.
    func recordCalendarReview(issuesFound: Int, issuesResolved: Int, preferences: AppPreferences = .shared) async {
        guard let context else { return }
        let review = CalendarReview(
            reviewedAt: Date(),
            daysAhead: 7,
            eventsScanned: CalendarService.shared.agendas.reduce(0) { $0 + $1.events.count },
            issuesFound: issuesFound,
            issuesResolved: issuesResolved
        )
        context.insert(review)
        try? context.save()

        preferences.lastCalendarReview = Date()
        NotificationService.shared.clearCalendarNudges()
        await rescheduleNotifications(preferences: preferences)
        WidgetRefresher.reloadAll()
    }

    // MARK: - Seeding

    /// First-run rituals. Chosen to cover all five domains from day one so the
    /// balance score means something before the user has configured anything.
    func seedRitualsIfNeeded(preferences: AppPreferences = .shared) {
        guard !preferences.hasSeededRituals, let context else { return }
        guard DayQueries.activeRituals(context: context).isEmpty else {
            preferences.hasSeededRituals = true
            return
        }

        let seeds: [(String, String, Domain, Cadence, Int, Int)] = [
            ("Deep work block", "90 minutes, no calendar, no inbox.", .business, .weekdays, 5, 9 * 60),
            ("Move", "Anything that raises your heart rate.", .body, .timesPerWeek, 4, 7 * 60),
            ("Read something long", "Twenty pages beats twenty tabs.", .mind, .daily, 7, 21 * 60),
            ("Reach out", "One message to someone who is not a client.", .relationships, .timesPerWeek, 3, 12 * 60),
            ("Shutdown ritual", "Close the laptop and mean it.", .recovery, .weekdays, 5, 18 * 60)
        ]

        for (index, seed) in seeds.enumerated() {
            let ritual = Ritual(
                name: seed.0,
                detail: seed.1,
                domain: seed.2,
                cadence: seed.3,
                targetPerWeek: seed.4,
                anchor: Date().startOfDay.settingTime(minutesFromMidnight: seed.5),
                sortIndex: index
            )
            context.insert(ritual)
        }
        try? context.save()
        preferences.hasSeededRituals = true
    }
}
