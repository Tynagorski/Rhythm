import Foundation
import SwiftData
import WidgetKit

/// Writes that must work from anywhere: the app, a notification action, or an
/// App Intent running inside the widget extension. Each one opens its own
/// context on the shared container, saves immediately, and reloads timelines —
/// so a tap on a widget and a tap in the app converge on the same state.
enum RitualMutator {

    @discardableResult
    static func setCompletion(ritualID: UUID, on day: Date, completed: Bool, isSkip: Bool = false) -> Bool {
        let context = ModelContext(RhythmStore.shared)
        guard let ritual = DayQueries.ritual(id: ritualID, context: context) else { return false }
        let start = day.startOfDay

        if let existing = DayQueries.entry(for: ritual, on: start) {
            if completed || isSkip {
                existing.isSkip = isSkip
                existing.completedAt = Date()
            } else {
                context.delete(existing)
            }
        } else if completed || isSkip {
            let entry = RitualEntry(day: start, isSkip: isSkip, ritual: ritual)
            context.insert(entry)
        }

        try? context.save()
        WidgetRefresher.reloadAll()
        return true
    }

    @discardableResult
    static func toggle(ritualID: UUID, on day: Date = Date()) -> Bool {
        let context = ModelContext(RhythmStore.shared)
        guard let ritual = DayQueries.ritual(id: ritualID, context: context) else { return false }
        let isDone = DayQueries.isCompleted(ritual, on: day)
        return setCompletion(ritualID: ritualID, on: day, completed: !isDone)
    }
}

enum PriorityMutator {

    @discardableResult
    static func setDone(priorityID: UUID, done: Bool) -> Bool {
        let context = ModelContext(RhythmStore.shared)
        guard let priority = DayQueries.priority(id: priorityID, context: context) else { return false }
        priority.setDone(done)
        try? context.save()
        WidgetRefresher.reloadAll()
        return true
    }

    @discardableResult
    static func toggle(priorityID: UUID) -> Bool {
        let context = ModelContext(RhythmStore.shared)
        guard let priority = DayQueries.priority(id: priorityID, context: context) else { return false }
        return setDone(priorityID: priorityID, done: !priority.isDone)
    }
}

enum WidgetRefresher {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func reload(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
