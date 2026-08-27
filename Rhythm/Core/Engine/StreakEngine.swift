import Foundation
import SwiftData

/// Streaks, computed on demand from entries rather than stored, so they can
/// never drift out of sync with the underlying record.
enum StreakEngine {

    /// Consecutive scheduled days a ritual has been kept, counting back from
    /// `today`. Days the ritual was not scheduled are stepped over, not broken;
    /// a deliberate skip pauses the streak rather than ending it.
    static func streak(for ritual: Ritual, today: Date = Date(), calendar: Calendar = .current) -> Int {
        let entriesByDay = Dictionary(
            ritual.entries.map { (calendar.startOfDay(for: $0.day), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: today)

        // Today only breaks a streak once it is over; an unkept ritual earlier
        // in the day should not zero out yesterday's work.
        if entriesByDay[cursor] == nil {
            cursor = cursor.adding(days: -1, calendar: calendar)
        }

        // Bounded so a corrupt store cannot spin forever.
        for _ in 0..<730 {
            guard ritual.isScheduled(on: cursor, calendar: calendar) else {
                cursor = cursor.adding(days: -1, calendar: calendar)
                continue
            }
            guard let entry = entriesByDay[cursor] else { break }
            if !entry.isSkip { streak += 1 }
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        return streak
    }

    /// Consecutive days that closed with a shutdown.
    static func shutdownStreak(context: ModelContext, today: Date = Date()) -> Int {
        let logs = DayQueries.recentDayLogs(days: 120, endingOn: today, context: context)
        let byDay = Dictionary(logs.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })

        var streak = 0
        var cursor = today.startOfDay
        if byDay[cursor]?.didShutDown != true { cursor = cursor.adding(days: -1) }
        while let log = byDay[cursor], log.didShutDown {
            streak += 1
            cursor = cursor.adding(days: -1)
        }
        return streak
    }

    /// Weekly adherence for a ritual: kept versus expected.
    static func weeklyAdherence(for ritual: Ritual, containing day: Date = Date()) -> (kept: Int, target: Int) {
        (DayQueries.completionsThisWeek(ritual, containing: day), ritual.weeklyTarget)
    }
}
