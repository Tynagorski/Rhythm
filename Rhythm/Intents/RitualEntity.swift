import AppIntents
import Foundation
import SwiftData

/// Exposes rituals to Siri and Shortcuts so "keep my move ritual" resolves to a
/// real record rather than a string match.
struct RitualEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Ritual" }
    static var defaultQuery = RitualEntityQuery()

    var id: UUID
    var name: String
    var domain: Domain

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(domain.title)",
            image: .init(systemName: domain.symbol)
        )
    }

    init(id: UUID, name: String, domain: Domain) {
        self.id = id
        self.name = name
        self.domain = domain
    }

    init(_ ritual: Ritual) {
        self.init(id: ritual.id, name: ritual.name, domain: ritual.domain)
    }
}

struct RitualEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [RitualEntity] {
        let context = ModelContextProvider.make()
        return identifiers.compactMap { id in
            DayQueries.ritual(id: id, context: context).map(RitualEntity.init)
        }
    }

    func suggestedEntities() async throws -> [RitualEntity] {
        let context = ModelContextProvider.make()
        return DayQueries.activeRituals(context: context).map(RitualEntity.init)
    }
}

extension RitualEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [RitualEntity] {
        let needle = string.lowercased()
        return try await suggestedEntities().filter { $0.name.lowercased().contains(needle) }
    }
}

/// App Intents can run in the app or in the widget extension. Both open a fresh
/// context on the same shared container.
enum ModelContextProvider {
    static func make() -> ModelContext { ModelContext(RhythmStore.shared) }
}
