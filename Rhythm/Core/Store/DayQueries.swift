import Foundation
import SwiftData

/// Fetch helpers shared by the app, the widget timeline providers and the App
/// Intents. Written as free functions over a `ModelContext` so they work in any
/// process without dragging view-model state along.
enum DayQueries {

    // MARK: - Priorities

    static func priorities(on day: Date, context: ModelContext) -> [Priority] {
        let start = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<Priority>(
            predicate: #Predicate<Priority> { $0.day == start },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func priorities(from start: Date, to end: Date, context: ModelContext) -> [Priority] {
        let lower = Calendar.current.startOfDay(for: start)
        let upper = Calendar.current.startOfDay(for: end)
        let descriptor = FetchDescriptor<Priority>(
            predicate: #Predicate<Priority> { $0.day >= lower && $0.day <= upper },
            sortBy: [SortDescriptor(\.day), SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func keystone(on day: Date, context: ModelContext) -> Priority? {
        priorities(on: day, context: context).first { $0.tier == .keystone }
    }

    static func priority(id: UUID, context: ModelContext) -> Priority? {
        var descriptor = FetchDescriptor<Priority>(predicate: #Predicate<Priority> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Rituals

    static func activeRituals(context: ModelContext) -> [Ritual] {
        let descriptor = FetchDescriptor<Ritual>(
            predicate: #Predicate<Ritual> { $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func ritual(id: UUID, context: ModelContext) -> Ritual? {
        var descriptor = FetchDescriptor<Ritual>(predicate: #Predicate<Ritual> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Rituals expected today, in anchor order. `.timesPerWeek` rituals appear
    /// only while the week's target is still unmet.
    static func ritualsDue(on day: Date, context: ModelContext) -> [Ritual] {
        let start = Calendar.current.startOfDay(for: day)
        return activeRituals(context: context)
            .filter { ritual in
                guard ritual.isScheduled(on: start) else { return false }
                guard ritual.cadence == .timesPerWeek else { return true }
                if isCompleted(ritual, on: start) { return true }
                return completionsThisWeek(ritual, containing: start) < ritual.weeklyTarget
            }
            .sorted { lhs, rhs in
                let l = AppPreferences.minutes(from: lhs.anchor)
                let r = AppPreferences.minutes(from: rhs.anchor)
                return l == r ? lhs.sortIndex < rhs.sortIndex : l < r
            }
    }

    static func entry(for ritual: Ritual, on day: Date) -> RitualEntry? {
        let start = Calendar.current.startOfDay(for: day)
        return ritual.entries.first { $0.day == start }
    }

    static func isCompleted(_ ritual: Ritual, on day: Date) -> Bool {
        guard let entry = entry(for: ritual, on: day) else { return false }
        return !entry.isSkip
    }

    static func completionsThisWeek(_ ritual: Ritual, containing day: Date) -> Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: day) else { return 0 }
        return ritual.entries.filter { !$0.isSkip && week.contains($0.day) }.count
    }

    // MARK: - Day logs

    static func dayLog(for day: Date, context: ModelContext) -> DayLog? {
        let start = Calendar.current.startOfDay(for: day)
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate<DayLog> { $0.day == start })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    static func dayLog(forOrCreating day: Date, context: ModelContext) -> DayLog {
        if let existing = dayLog(for: day, context: context) { return existing }
        let log = DayLog(day: day)
        context.insert(log)
        return log
    }

    static func recentDayLogs(days: Int, endingOn day: Date = Date(), context: ModelContext) -> [DayLog] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: day)
        guard let start = cal.date(byAdding: .day, value: -(max(1, days) - 1), to: end) else { return [] }
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate<DayLog> { $0.day >= start && $0.day <= end },
            sortBy: [SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Calendar reviews

    static func lastCalendarReview(context: ModelContext) -> CalendarReview? {
        var descriptor = FetchDescriptor<CalendarReview>(
            sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
