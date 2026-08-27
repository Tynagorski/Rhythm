import Foundation
import SwiftData

/// Bridges persisted state and the pure scoring engine: reads a day out of
/// SwiftData, folds in the calendar load, scores it, and writes the result back
/// to the day's `DayLog`.
enum DayAssembler {

    static func input(
        for day: Date,
        context: ModelContext,
        agenda: DayAgenda?,
        preferences: AppPreferences = .shared
    ) -> BalanceInput {
        let start = day.startOfDay
        let priorities = DayQueries.priorities(on: start, context: context)
        let due = DayQueries.ritualsDue(on: start, context: context)

        var input = BalanceInput()
        input.priorities = priorities.map {
            .init(tier: $0.tier, domain: $0.domain, isDone: $0.isDone)
        }
        input.rituals = due.map { ritual in
            let entry = DayQueries.entry(for: ritual, on: start)
            return .init(domain: ritual.domain, isDone: entry.map { !$0.isSkip } ?? false, isSkip: entry?.isSkip ?? false)
        }
        input.meetingMinutes = agenda?.meetingMinutes ?? 0
        input.afterHoursMinutes = agenda?.afterHoursMinutes ?? 0
        // With no calendar access there is no evidence the day was fragmented,
        // so assume a clear runway rather than penalising the user for a
        // permission they declined.
        input.longestFreeBlockMinutes = agenda?.longestFreeBlockMinutes ?? 240
        input.boundaries = DayBoundaries(preferences: preferences)
        input.isWeekend = Calendar.current.isDateInWeekend(start)
        input.didShutDown = DayQueries.dayLog(for: start, context: context)?.didShutDown ?? false
        return input
    }

    /// Scores the day and persists the result. Returns the result so callers can
    /// render it without a second fetch.
    @discardableResult
    static func recompute(
        day: Date,
        context: ModelContext,
        agenda: DayAgenda?,
        preferences: AppPreferences = .shared
    ) -> BalanceResult {
        let start = day.startOfDay
        let result = BalanceEngine.evaluate(input(for: start, context: context, agenda: agenda, preferences: preferences))
        let log = DayQueries.dayLog(forOrCreating: start, context: context)
        log.balanceScore = result.score
        log.executionScore = result.execution
        log.recoveryScore = result.protection
        log.loadMinutes = result.meetingMinutes
        log.afterHoursMinutes = result.afterHoursMinutes
        log.coveredDomains = result.coveredDomains
        try? context.save()
        return result
    }

    /// Which domains have been fed recently, derived from completed priorities
    /// and ritual entries across the window.
    static func drift(context: ModelContext, windowDays: Int = 14, today: Date = Date()) -> DriftReport {
        let end = today.startOfDay
        let start = end.adding(days: -(max(1, windowDays) - 1))

        var touches: [Domain: [Date]] = [:]
        for priority in DayQueries.priorities(from: start, to: end, context: context) where priority.isDone {
            touches[priority.domain, default: []].append(priority.day)
        }
        for ritual in DayQueries.activeRituals(context: context) {
            let days = ritual.entries
                .filter { !$0.isSkip && $0.day >= start && $0.day <= end }
                .map(\.day)
            if !days.isEmpty { touches[ritual.domain, default: []].append(contentsOf: days) }
        }
        return BalanceEngine.drift(touches: touches, today: end, windowDays: windowDays)
    }

    /// Rolling average of the persisted daily scores. Days with no log at all
    /// are skipped rather than counted as zero — an untracked day is unknown,
    /// not bad.
    static func rollingScore(days: Int = 7, context: ModelContext, today: Date = Date()) -> Int? {
        let logs = DayQueries.recentDayLogs(days: days, endingOn: today, context: context)
            .filter { $0.balanceScore > 0 }
        guard !logs.isEmpty else { return nil }
        return Int((Double(logs.reduce(0) { $0 + $1.balanceScore }) / Double(logs.count)).rounded())
    }
}
