import Foundation
import SwiftData

/// Owns the single `ModelContainer` shared by the app, the widget extension and
/// the App Intents that run inside it.
enum RhythmStore {
    static let schema = Schema([
        Priority.self,
        Ritual.self,
        RitualEntry.self,
        DayLog.self,
        CalendarReview.self
    ])

    /// Built once per process. If the App Group container cannot be opened —
    /// which in practice means the entitlement is missing or provisioning is
    /// broken — we fall back to a process-local store so the UI still works
    /// instead of crashing on launch. Widgets would show empty data in that
    /// case, which is the correct signal that something needs fixing.
    static let shared: ModelContainer = {
        if let container = try? makeContainer(groupIdentifier: AppGroup.identifier) {
            return container
        }
        if let container = try? makeContainer(groupIdentifier: nil) {
            return container
        }
        // Last resort: an in-memory store. Data will not persist, but the app
        // launches and the user can be told what happened.
        // swiftlint:disable:next force_try
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }()

    static func makeContainer(groupIdentifier: String?) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let groupIdentifier {
            configuration = ModelConfiguration(
                "Rhythm",
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(groupIdentifier),
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration("Rhythm", schema: schema, isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// For previews and tests.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}
