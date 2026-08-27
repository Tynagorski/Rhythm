import Foundation

/// Everything one day's score is computed from, as plain values. Building this
/// separately from scoring it means the formula can be unit tested exhaustively
/// without SwiftData, EventKit or a running app.
struct BalanceInput: Sendable {
    struct PlannedPriority: Sendable {
        var tier: PriorityTier
        var domain: Domain
        var isDone: Bool
    }

    struct DueRitual: Sendable {
        var domain: Domain
        var isDone: Bool
        var isSkip: Bool
    }

    var priorities: [PlannedPriority] = []
    var rituals: [DueRitual] = []
    var meetingMinutes: Int = 0
    var afterHoursMinutes: Int = 0
    var longestFreeBlockMinutes: Int = 0
    var boundaries: DayBoundaries = DayBoundaries(startMinutes: 8 * 60, endMinutes: 18 * 60)
    var isWeekend: Bool = false
    var didShutDown: Bool = false
}

/// The score, broken into the parts that produced it. Rhythm always shows the
/// breakdown — a single opaque number is something to game, a breakdown is
/// something to act on.
struct BalanceResult: Sendable, Hashable {
    var score: Int
    var execution: Int
    var rituals: Int
    var coverage: Int
    var protection: Int
    var coveredDomains: Set<Domain>
    var meetingMinutes: Int
    var afterHoursMinutes: Int
    /// The single most useful sentence about this day.
    var headline: String

    static let empty = BalanceResult(
        score: 0, execution: 0, rituals: 0, coverage: 0, protection: 0,
        coveredDomains: [], meetingMinutes: 0, afterHoursMinutes: 0,
        headline: "No plan yet."
    )
}

/// How long each domain has gone untouched.
struct DriftReport: Sendable, Hashable {
    /// Days since the domain last saw a completed priority or ritual. A domain
    /// absent from the dictionary was never touched inside the window.
    var daysSinceTouched: [Domain: Int]
    var windowDays: Int

    /// A domain never touched inside the window is treated as stale for the
    /// whole window, so it sorts as the worst case rather than disappearing.
    func staleness(_ domain: Domain) -> Int {
        daysSinceTouched[domain] ?? windowDays
    }

    /// Domains starved for three days or more, worst first. Three days is where
    /// "busy week" turns into a pattern.
    var starved: [Domain] {
        Domain.allCases
            .filter { staleness($0) >= 3 }
            .sorted { staleness($0) > staleness($1) }
    }

    var worst: Domain? { starved.first }
}

enum BalanceEngine {

    /// Relative importance of each component. They sum to 1; when a component
    /// has no data for the day (nothing planned, no rituals due) it is dropped
    /// and the remaining weights are renormalised rather than scoring a zero
    /// for something the user never signed up for.
    private enum Weight {
        static let execution = 0.30
        static let rituals = 0.25
        static let coverage = 0.25
        static let protection = 0.20
    }

    static func evaluate(_ input: BalanceInput) -> BalanceResult {
        var components: [(value: Double, weight: Double)] = []

        let execution = executionRatio(input)
        if let execution { components.append((execution, Weight.execution)) }

        let rituals = ritualRatio(input)
        if let rituals { components.append((rituals, Weight.rituals)) }

        let coverage = coverageRatio(input)
        components.append((coverage, Weight.coverage))

        let protection = protectionRatio(input)
        components.append((protection, Weight.protection))

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weighted = totalWeight > 0
            ? components.reduce(0) { $0 + $1.value * $1.weight } / totalWeight
            : 0

        // Closing the day out is a small, deliberate bonus: it is the habit that
        // makes every other number in the app trustworthy.
        let shutdownBonus = input.didShutDown ? 0.03 : 0
        let score = clampPercent(weighted + shutdownBonus)

        let covered = coveredDomains(input)
        return BalanceResult(
            score: score,
            execution: clampPercent(execution ?? 0),
            rituals: clampPercent(rituals ?? 0),
            coverage: clampPercent(coverage),
            protection: clampPercent(protection),
            coveredDomains: covered,
            meetingMinutes: input.meetingMinutes,
            afterHoursMinutes: input.afterHoursMinutes,
            headline: headline(for: input, score: score, covered: covered, protection: protection)
        )
    }

    // MARK: - Components

    /// Weighted completion of what was planned. `nil` when nothing was planned.
    static func executionRatio(_ input: BalanceInput) -> Double? {
        guard !input.priorities.isEmpty else { return nil }
        let planned = input.priorities.reduce(0.0) { $0 + $1.tier.weight }
        guard planned > 0 else { return nil }
        let done = input.priorities.reduce(0.0) { $0 + ($1.isDone ? $1.tier.weight : 0) }
        return done / planned
    }

    /// Ritual adherence. Deliberate skips shrink the denominator instead of
    /// counting as misses — the app rewards honesty over a padded streak.
    static func ritualRatio(_ input: BalanceInput) -> Double? {
        let counted = input.rituals.filter { !$0.isSkip }
        guard !counted.isEmpty else { return nil }
        let done = counted.filter(\.isDone).count
        return Double(done) / Double(counted.count)
    }

    /// Did the day touch more than one part of a life? Weighted so that a day
    /// spent entirely on business cannot score well here.
    static func coverageRatio(_ input: BalanceInput) -> Double {
        let covered = coveredDomains(input)
        guard !covered.isEmpty else { return 0 }
        let earned = covered.reduce(0.0) { $0 + $1.coverageWeight }
        let available = Domain.allCases.reduce(0.0) { $0 + $1.coverageWeight }
        return min(1, earned / available)
    }

    static func coveredDomains(_ input: BalanceInput) -> Set<Domain> {
        var covered = Set<Domain>()
        for priority in input.priorities where priority.isDone { covered.insert(priority.domain) }
        for ritual in input.rituals where ritual.isDone { covered.insert(ritual.domain) }
        return covered
    }

    /// How well the day's boundaries held. On weekends the work-shaped penalties
    /// are dropped: a Saturday with no meetings is not an unprotected day.
    static func protectionRatio(_ input: BalanceInput) -> Double {
        guard !input.isWeekend else {
            // A weekend loses protection only to work that spilled into it.
            let spill = min(1, Double(input.meetingMinutes) / 240)
            return max(0, 1 - spill)
        }

        let afterHours = min(1, Double(input.afterHoursMinutes) / 120)

        let workday = Double(max(60, input.boundaries.lengthMinutes))
        let saturation = Double(input.meetingMinutes) / workday
        // Under 60% booked costs nothing; fully booked costs everything.
        let saturationPenalty = min(1, max(0, (saturation - 0.6) / 0.4))

        // Deep work needs at least a 90-minute runway.
        let focusPenalty = input.longestFreeBlockMinutes >= 90
            ? 0
            : Double(90 - max(0, input.longestFreeBlockMinutes)) / 90

        let penalty = 0.45 * afterHours + 0.35 * saturationPenalty + 0.20 * focusPenalty
        return max(0, 1 - penalty)
    }

    // MARK: - Copy

    static func headline(for input: BalanceInput, score: Int, covered: Set<Domain>, protection: Double) -> String {
        if input.priorities.isEmpty && input.rituals.isEmpty {
            return "Nothing planned yet. Set one keystone and the day has a spine."
        }
        if input.afterHoursMinutes >= 90 {
            return "\(input.afterHoursMinutes.durationLabel) landed outside your hours. That is the leak."
        }
        let missing = Set(Domain.allCases).subtracting(covered)
        if score >= 80, missing.isEmpty {
            return "Full coverage and the boundaries held. This is the day to repeat."
        }
        if score >= 80 {
            return "Strong day. \(missing.map(\.shortTitle).sorted().joined(separator: " and ")) went untouched."
        }
        if protection < 0.5 {
            return "The calendar ran the day. Protect one block tomorrow before anyone else can book it."
        }
        if let starved = missing.sorted(by: { $0.coverageWeight > $1.coverageWeight }).first {
            return "Business is fed. \(starved.shortTitle) is not — give it fifteen minutes tomorrow."
        }
        return "Solid execution. Keep the shutdown honest and it compounds."
    }

    // MARK: - Drift

    /// `touches` maps a domain to the days it was touched. Days are expected to
    /// be start-of-day.
    static func drift(touches: [Domain: [Date]], today: Date = Date(), windowDays: Int = 14) -> DriftReport {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: today)
        var result: [Domain: Int] = [:]
        for domain in Domain.allCases {
            let days = touches[domain] ?? []
            guard let latest = days.map({ calendar.startOfDay(for: $0) }).max() else { continue }
            result[domain] = max(0, calendar.dateComponents([.day], from: latest, to: end).day ?? 0)
        }
        return DriftReport(daysSinceTouched: result, windowDays: max(1, windowDays))
    }

    // MARK: - Helpers

    private static func clampPercent(_ ratio: Double) -> Int {
        Int((max(0, min(1, ratio)) * 100).rounded())
    }
}
