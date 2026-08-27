import Foundation
import SwiftData

/// The flattened state a widget timeline entry needs. Built once per timeline
/// refresh from the shared store, so no SwiftData object crosses into the view
/// layer of the extension.
struct WidgetSnapshot: Sendable {
    struct RitualItem: Identifiable, Sendable {
        let id: UUID
        let name: String
        let domain: Domain
        let isDone: Bool
    }

    struct PriorityItem: Identifiable, Sendable {
        let id: UUID
        let title: String
        let domain: Domain
        let isDone: Bool
    }

    var score: Int
    var execution: Int
    var coverage: Int
    var protection: Int
    var headline: String
    var keystone: PriorityItem?
    var momentum: [PriorityItem]
    var rituals: [RitualItem]
    var coveredDomains: Set<Domain>
    var daysSinceCalendarReview: Int?
    var calendarReviewIntervalDays: Int
    var driftDomain: Domain?
    var driftDays: Int

    var calendarIsStale: Bool {
        guard let days = daysSinceCalendarReview else { return true }
        return days >= calendarReviewIntervalDays
    }

    var ritualsKept: Int { rituals.filter(\.isDone).count }

    /// Reads the shared store. Any failure yields the placeholder rather than an
    /// empty widget, so a provisioning problem shows as sample data instead of a
    /// blank tile.
    static func current(preferences: AppPreferences = .shared) -> WidgetSnapshot {
        let context = ModelContext(RhythmStore.shared)
        let day = Date().startOfDay

        let priorities = DayQueries.priorities(on: day, context: context)
        let due = DayQueries.ritualsDue(on: day, context: context)
        let result = BalanceEngine.evaluate(
            DayAssembler.input(for: day, context: context, agenda: nil, preferences: preferences)
        )
        let drift = DayAssembler.drift(context: context)

        return WidgetSnapshot(
            score: result.score,
            execution: result.execution,
            coverage: result.coverage,
            protection: result.protection,
            headline: result.headline,
            keystone: priorities.first { $0.tier == .keystone }.map {
                PriorityItem(id: $0.id, title: $0.title, domain: $0.domain, isDone: $0.isDone)
            },
            momentum: priorities.filter { $0.tier == .momentum }.map {
                PriorityItem(id: $0.id, title: $0.title, domain: $0.domain, isDone: $0.isDone)
            },
            rituals: due.map {
                RitualItem(
                    id: $0.id,
                    name: $0.name,
                    domain: $0.domain,
                    isDone: DayQueries.isCompleted($0, on: day)
                )
            },
            coveredDomains: result.coveredDomains,
            daysSinceCalendarReview: preferences.daysSinceCalendarReview,
            calendarReviewIntervalDays: preferences.calendarReviewIntervalDays,
            driftDomain: drift.worst,
            driftDays: drift.worst.map(drift.staleness) ?? 0
        )
    }

    /// Used for the widget gallery and for redacted placeholders.
    static let placeholder = WidgetSnapshot(
        score: 74,
        execution: 80,
        coverage: 70,
        protection: 65,
        headline: "Strong day. Recovery went untouched.",
        keystone: PriorityItem(id: UUID(), title: "Finish the board deck", domain: .business, isDone: false),
        momentum: [
            PriorityItem(id: UUID(), title: "Close the Whitman loop", domain: .business, isDone: true),
            PriorityItem(id: UUID(), title: "Draft Q3 hiring plan", domain: .business, isDone: false)
        ],
        rituals: [
            RitualItem(id: UUID(), name: "Deep work", domain: .business, isDone: true),
            RitualItem(id: UUID(), name: "Move", domain: .body, isDone: true),
            RitualItem(id: UUID(), name: "Read", domain: .mind, isDone: false),
            RitualItem(id: UUID(), name: "Reach out", domain: .relationships, isDone: false)
        ],
        coveredDomains: [.business, .body],
        daysSinceCalendarReview: 4,
        calendarReviewIntervalDays: 3,
        driftDomain: .recovery,
        driftDays: 5
    )
}
