import Foundation
import SwiftData

/// How often a ritual is expected. Cadence drives both "is it due today" and
/// the denominator of its weekly completion rate.
enum Cadence: String, CaseIterable, Codable, Sendable {
    case daily
    case weekdays
    case weekends
    case timesPerWeek

    var title: String {
        switch self {
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .timesPerWeek: "Times per week"
        }
    }
}

@Model
final class Ritual {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var domainRaw: String
    var cadenceRaw: String
    /// Only meaningful when cadence is `.timesPerWeek`.
    var targetPerWeek: Int
    /// Time of day this ritual is anchored to. Only the hour/minute are used.
    var anchor: Date
    var remindersEnabled: Bool
    var isArchived: Bool
    var sortIndex: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RitualEntry.ritual)
    var entries: [RitualEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        detail: String = "",
        domain: Domain,
        cadence: Cadence = .daily,
        targetPerWeek: Int = 3,
        anchor: Date,
        remindersEnabled: Bool = true,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.domainRaw = domain.rawValue
        self.cadenceRaw = cadence.rawValue
        self.targetPerWeek = targetPerWeek
        self.anchor = anchor
        self.remindersEnabled = remindersEnabled
        self.isArchived = false
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var domain: Domain {
        get { Domain(rawValue: domainRaw) ?? .business }
        set { domainRaw = newValue.rawValue }
    }

    var cadence: Cadence {
        get { Cadence(rawValue: cadenceRaw) ?? .daily }
        set { cadenceRaw = newValue.rawValue }
    }

    /// Expected completions in a week — the denominator for adherence.
    var weeklyTarget: Int {
        switch cadence {
        case .daily: 7
        case .weekdays: 5
        case .weekends: 2
        case .timesPerWeek: max(1, min(7, targetPerWeek))
        }
    }

    /// A `.timesPerWeek` ritual is never "due" on a specific day — it is due
    /// until the week's target is met — so callers should check `isSatisfied`
    /// for the week rather than treating a false here as a miss.
    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        let isWeekend = calendar.isDateInWeekend(date)
        switch cadence {
        case .daily: return true
        case .weekdays: return !isWeekend
        case .weekends: return isWeekend
        case .timesPerWeek: return true
        }
    }

    func anchorComponents(calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: anchor)
    }
}

@Model
final class RitualEntry {
    @Attribute(.unique) var id: UUID
    /// Start of the day the entry counts toward.
    var day: Date
    var completedAt: Date
    /// A deliberate skip. Skips break neither the streak nor the score as
    /// harshly as a silent miss — the point is honesty, not perfection.
    var isSkip: Bool
    var ritual: Ritual?

    init(id: UUID = UUID(), day: Date, completedAt: Date = Date(), isSkip: Bool = false, ritual: Ritual? = nil) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.completedAt = completedAt
        self.isSkip = isSkip
        self.ritual = ritual
    }
}
