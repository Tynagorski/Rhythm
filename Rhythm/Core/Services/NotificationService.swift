import Foundation
import UserNotifications
import UIKit

@MainActor
@Observable
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// Set when a notification action asks the app to navigate. The root view
    /// observes this and clears it once handled.
    var pendingRoute: RhythmRoute?

    var isAuthorized: Bool {
        authorization == .authorized || authorization == .provisional || authorization == .ephemeral
    }

    // MARK: - Setup

    func bootstrap() {
        center.delegate = self
        registerCategories()
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Requests alerts, sounds and badges, then registers for remote
    /// notifications so the server-driven coaching nudges can arrive too.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .providesAppNotificationSettings])
            await refreshAuthorization()
            if granted { registerForRemoteNotifications() }
            return granted
        } catch {
            await refreshAuthorization()
            return false
        }
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func registerCategories() {
        let calendarReview = UNNotificationCategory(
            identifier: RhythmNotification.Category.calendarReview,
            actions: [
                UNNotificationAction(
                    identifier: RhythmNotification.Action.reviewNow,
                    title: "Review now",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: RhythmNotification.Action.remindTomorrow,
                    title: "Tomorrow",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let ritual = UNNotificationCategory(
            identifier: RhythmNotification.Category.ritual,
            actions: [
                UNNotificationAction(
                    identifier: RhythmNotification.Action.completeRitual,
                    title: "Done",
                    options: []
                ),
                UNNotificationAction(
                    identifier: RhythmNotification.Action.skipRitual,
                    title: "Skip today",
                    options: [.destructive]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let shutdown = UNNotificationCategory(
            identifier: RhythmNotification.Category.shutdown,
            actions: [
                UNNotificationAction(
                    identifier: RhythmNotification.Action.startShutdown,
                    title: "Close out the day",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let brief = UNNotificationCategory(
            identifier: RhythmNotification.Category.brief,
            actions: [
                UNNotificationAction(
                    identifier: RhythmNotification.Action.openPlan,
                    title: "Open plan",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([calendarReview, ritual, shutdown, brief])
    }

    // MARK: - Scheduling

    /// Rebuilds the entire local schedule. Cheap enough to call on every
    /// meaningful state change, which keeps the schedule and the data in step
    /// without incremental bookkeeping.
    func rescheduleAll(
        preferences: AppPreferences = .shared,
        rituals: [RitualReminder] = [],
        drift: DriftReport? = nil
    ) async {
        guard isAuthorized else { return }

        let existing = await center.pendingNotificationRequests()
        let ours = existing.map(\.identifier).filter { $0.hasPrefix("rhythm.") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        var requests: [UNNotificationRequest] = []

        if preferences.morningBriefEnabled {
            requests.append(dailyRequest(
                id: RhythmNotification.morningBrief,
                at: preferences.morningBrief,
                title: "Today's rhythm",
                body: "Name your keystone before the day names it for you.",
                category: RhythmNotification.Category.brief,
                route: .today,
                skipWeekends: preferences.quietWeekends
            ))
        }

        if preferences.middayCheckEnabled {
            requests.append(dailyRequest(
                id: RhythmNotification.middayCheck,
                at: preferences.middayCheck,
                title: "Halfway",
                body: "Is the keystone still standing, or has the day taken it?",
                category: RhythmNotification.Category.brief,
                route: .today,
                skipWeekends: preferences.quietWeekends
            ))
        }

        if preferences.shutdownEnabled {
            requests.append(dailyRequest(
                id: RhythmNotification.shutdown,
                at: AppPreferences.components(fromMinutes: preferences.workdayEndMinutes),
                title: "Hard stop",
                body: "Close the day out: log it, set tomorrow's keystone, put it down.",
                category: RhythmNotification.Category.shutdown,
                route: .shutdown,
                skipWeekends: preferences.quietWeekends
            ))
        }

        // Sunday evening review.
        requests.append(weeklyRequest(
            id: RhythmNotification.weeklyReset,
            weekday: 1,
            hour: 17,
            minute: 0,
            title: "Weekly reset",
            body: "Fifteen minutes now buys back the week. Review the calendar and reset your rituals.",
            category: RhythmNotification.Category.calendarReview,
            route: .balance
        ))

        if preferences.calendarNudgeEnabled {
            requests.append(contentsOf: calendarNudgeRequests(preferences: preferences))
        }

        if preferences.ritualRemindersEnabled {
            requests.append(contentsOf: rituals.compactMap(ritualRequest(_:)))
        }

        if preferences.driftAlertsEnabled, let drift, let starved = drift.worst {
            requests.append(driftRequest(domain: starved, days: drift.staleness(starved)))
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// The calendar nudge is the app's one deliberately insistent notification.
    /// It fires the day the calendar goes stale and escalates for two days after
    /// — then stops, because an alert that never stops is an alert you turn off.
    private func calendarNudgeRequests(preferences: AppPreferences) -> [UNNotificationRequest] {
        let interval = preferences.calendarReviewIntervalDays
        let anchor = preferences.lastCalendarReview ?? Date()
        let calendar = Calendar.current

        let copy: [(String, String)] = [
            ("Your calendar is going stale",
             "It has been \(interval) days. Five minutes now, or a surprise later."),
            ("Still unreviewed",
             "Next week is already being booked by other people. Take it back."),
            ("Last nudge on this",
             "Rhythm can only tell you what your calendar says. Make it say the truth.")
        ]

        return copy.enumerated().compactMap { index, text in
            guard let fireDay = calendar.date(byAdding: .day, value: interval + index, to: anchor.startOfDay) else {
                return nil
            }
            // 9am on the day it goes stale.
            let fire = fireDay.settingTime(minutesFromMidnight: 9 * 60)
            guard fire > Date() else { return nil }

            let content = UNMutableNotificationContent()
            content.title = text.0
            content.body = text.1
            content.sound = .default
            content.categoryIdentifier = RhythmNotification.Category.calendarReview
            content.userInfo = [RhythmNotification.UserInfoKey.route: RhythmRoute.calendarReview.rawValue]
            content.interruptionLevel = index == 0 ? .active : .timeSensitive
            content.relevanceScore = 1.0

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            return UNNotificationRequest(
                identifier: RhythmNotification.calendarNudge(step: index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    private func ritualRequest(_ reminder: RitualReminder) -> UNNotificationRequest? {
        guard reminder.remindersEnabled else { return nil }
        let content = UNMutableNotificationContent()
        content.title = reminder.name
        content.body = reminder.detail.isEmpty ? "\(reminder.domain.title) · time to keep it." : reminder.detail
        content.sound = .default
        content.categoryIdentifier = RhythmNotification.Category.ritual
        content.userInfo = [
            RhythmNotification.UserInfoKey.route: RhythmRoute.rituals.rawValue,
            RhythmNotification.UserInfoKey.ritualID: reminder.id.uuidString
        ]
        content.threadIdentifier = "rituals"

        var components = reminder.anchor
        components.second = 0
        return UNNotificationRequest(
            identifier: RhythmNotification.ritual(reminder.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func driftRequest(domain: Domain, days: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(domain.title) has gone quiet"
        content.body = "\(days) days without a single \(domain.shortTitle.lowercased()) entry. Put something small on tomorrow."
        content.sound = .default
        content.categoryIdentifier = RhythmNotification.Category.brief
        content.userInfo = [RhythmNotification.UserInfoKey.route: RhythmRoute.balance.rawValue]

        // Tomorrow morning, not right now: drift is a pattern, not an emergency.
        let fire = Date().adding(days: 1).settingTime(minutesFromMidnight: 8 * 60 + 30)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        return UNNotificationRequest(
            identifier: RhythmNotification.driftAlert,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func dailyRequest(
        id: String,
        at time: DateComponents,
        title: String,
        body: String,
        category: String,
        route: RhythmRoute,
        skipWeekends: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = [RhythmNotification.UserInfoKey.route: route.rawValue]

        var components = time
        components.second = 0
        // `UNCalendarNotificationTrigger` cannot express "weekdays only" in one
        // trigger, so quiet weekends are enforced when the notification is
        // delivered instead.
        if skipWeekends { content.userInfo["weekdaysOnly"] = true }

        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func weeklyRequest(
        id: String,
        weekday: Int,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        category: String,
        route: RhythmRoute
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = [RhythmNotification.UserInfoKey.route: route.rawValue]

        let components = DateComponents(hour: hour, minute: minute, weekday: weekday)
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    /// Clears the escalating calendar nudges the moment a review completes.
    func clearCalendarNudges() {
        NotificationCleanup.clearCalendarNudges()
    }

    func setBadge(_ count: Int) {
        Task { try? await center.setBadgeCount(max(0, count)) }
    }
}

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        if info["weekdaysOnly"] as? Bool == true, Calendar.current.isDateInWeekend(Date()) {
            return []
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case RhythmNotification.Action.remindTomorrow:
            AppPreferences.shared.lastCalendarReview = (AppPreferences.shared.lastCalendarReview ?? Date())
                .adding(days: 1)
            await rescheduleAll()
            return

        case RhythmNotification.Action.completeRitual, RhythmNotification.Action.skipRitual:
            if let raw = info[RhythmNotification.UserInfoKey.ritualID] as? String,
               let id = UUID(uuidString: raw) {
                let isSkip = response.actionIdentifier == RhythmNotification.Action.skipRitual
                RitualMutator.setCompletion(ritualID: id, on: Date(), completed: !isSkip, isSkip: isSkip)
            }
            return

        default:
            break
        }

        if let route = RhythmRoute(userInfo: info) {
            pendingRoute = route
        } else {
            pendingRoute = .today
        }
    }

    /// The system offers this when the user taps "Settings" on a notification.
    /// Rhythm has its own per-notification toggles, so send them there.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        pendingRoute = .settings
    }
}
