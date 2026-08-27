import AppIntents
import SwiftData
import SwiftUI

/// Backs the check circles in the interactive widgets, and doubles as a
/// Shortcuts action. Because it writes through `RitualMutator`, a tap on the
/// home screen and a tap in the app land in exactly the same place.
struct CompleteRitualIntent: AppIntent {
    static var title: LocalizedStringResource = "Keep a ritual"
    static var description = IntentDescription("Marks a ritual as kept for today.")
    /// The widget updates in place; there is no reason to foreground the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Ritual")
    var ritual: RitualEntity

    @Parameter(title: "Skip instead", default: false)
    var isSkip: Bool

    init() {}

    init(ritual: RitualEntity, isSkip: Bool = false) {
        self.ritual = ritual
        self.isSkip = isSkip
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Keep \(\.$ritual)") {
            \.$isSkip
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        RitualMutator.setCompletion(ritualID: ritual.id, on: Date(), completed: !isSkip, isSkip: isSkip)
        return .result(dialog: isSkip
                       ? "Skipped \(ritual.name) for today."
                       : "\(ritual.name) kept.")
    }
}

/// Toggle used by the widget buttons, where the current state is already known
/// and a second tap should undo the first.
struct ToggleRitualIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle a ritual"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Ritual ID")
    var ritualID: String

    init() {}

    init(ritualID: UUID) {
        self.ritualID = ritualID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: ritualID) {
            RitualMutator.toggle(ritualID: id)
        }
        return .result()
    }
}

/// Ticks any of today's priorities straight off the home screen.
struct TogglePriorityIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle a priority"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Priority ID")
    var priorityID: String

    init() {}

    init(priorityID: UUID) {
        self.priorityID = priorityID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: priorityID) {
            PriorityMutator.toggle(priorityID: id)
        }
        return .result()
    }
}

/// "Set my keystone to ship the pricing deck." Creates or replaces today's
/// keystone without opening the app.
struct SetKeystoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Set today's keystone"
    static var description = IntentDescription("Names the one thing that makes today count.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Keystone", requestValueDialog: "What is the one thing today?")
    var keystone: String

    @Parameter(title: "Domain", default: .business)
    var domain: DomainAppEnum

    init() {}

    init(title: String, domain: DomainAppEnum = .business) {
        self.keystone = title
        self.domain = domain
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set today's keystone to \(\.$keystone)") {
            \.$domain
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContextProvider.make()
        let day = Date().startOfDay

        for existing in DayQueries.priorities(on: day, context: context) where existing.tier == .keystone {
            existing.tier = .momentum
        }
        context.insert(Priority(
            title: keystone,
            tier: .keystone,
            domain: domain.domain,
            day: day
        ))
        try? context.save()
        WidgetRefresher.reloadAll()

        return .result(dialog: "Keystone set: \(keystone).")
    }
}

/// "Mark my calendar reviewed." Resets the staleness clock from Siri, for the
/// case where you just did the review in Calendar itself.
struct LogCalendarReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a calendar review"
    static var description = IntentDescription("Records that you have reviewed the week ahead.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContextProvider.make()
        context.insert(CalendarReview(reviewedAt: Date()))
        try? context.save()

        AppPreferences.shared.lastCalendarReview = Date()
        NotificationCleanup.clearCalendarNudges()
        WidgetRefresher.reloadAll()

        return .result(dialog: "Calendar marked reviewed. Next nudge in \(AppPreferences.shared.calendarReviewIntervalDays) days.")
    }
}

/// Reads today's score back without opening the app.
struct BalanceCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Check my balance"
    static var description = IntentDescription("Reports today's balance score and what is pulling it down.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContextProvider.make()
        let result = BalanceEngine.evaluate(
            DayAssembler.input(for: Date(), context: context, agenda: nil)
        )
        return .result(dialog: "\(result.score) out of 100. \(result.headline)")
    }
}

/// SwiftData enums are fine, but App Intents needs its own `AppEnum`.
enum DomainAppEnum: String, AppEnum {
    case business, body, mind, relationships, recovery

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Domain" }

    static var caseDisplayRepresentations: [DomainAppEnum: DisplayRepresentation] = [
        .business: "Business",
        .body: "Body",
        .mind: "Mind",
        .relationships: "Relationships",
        .recovery: "Recovery"
    ]

    var domain: Domain { Domain(rawValue: rawValue) ?? .business }
}

struct RhythmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetKeystoneIntent(),
            phrases: [
                "Set my keystone in \(.applicationName)",
                "What is my one thing in \(.applicationName)"
            ],
            shortTitle: "Set keystone",
            systemImageName: "target"
        )
        AppShortcut(
            intent: BalanceCheckIntent(),
            phrases: [
                "How is my balance in \(.applicationName)",
                "Check my \(.applicationName) score"
            ],
            shortTitle: "Check balance",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: LogCalendarReviewIntent(),
            phrases: [
                "Mark my calendar reviewed in \(.applicationName)",
                "I reviewed my calendar in \(.applicationName)"
            ],
            shortTitle: "Calendar reviewed",
            systemImageName: "calendar.badge.checkmark"
        )
        AppShortcut(
            intent: CompleteRitualIntent(),
            phrases: [
                "Keep a ritual in \(.applicationName)",
                "Log a \(.applicationName) ritual"
            ],
            shortTitle: "Keep ritual",
            systemImageName: "repeat.circle.fill"
        )
    }
}
