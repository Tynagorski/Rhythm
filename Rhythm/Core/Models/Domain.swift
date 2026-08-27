import SwiftUI

/// The five life domains Rhythm balances. Coverage across all five — not raw
/// output in any one — is what the balance score rewards.
enum Domain: String, CaseIterable, Codable, Identifiable, Sendable {
    case business
    case body
    case mind
    case relationships
    case recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .business: "Business"
        case .body: "Body"
        case .mind: "Mind"
        case .relationships: "Relationships"
        case .recovery: "Recovery"
        }
    }

    /// Shown in insight copy, e.g. "Recovery has been starved for 4 days."
    var shortTitle: String {
        switch self {
        case .relationships: "People"
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .business: "briefcase.fill"
        case .body: "figure.run"
        case .mind: "brain.head.profile"
        case .relationships: "person.2.fill"
        case .recovery: "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .business: Palette.business
        case .body: Palette.body
        case .mind: Palette.mind
        case .relationships: Palette.relationships
        case .recovery: Palette.recovery
        }
    }

    /// Domains that belong to the "work" half of work/life.
    var isWork: Bool { self == .business }

    /// Weight in the daily coverage component of the balance score. Business is
    /// weighted lower on purpose: a top performer will always feed it, so
    /// rewarding it further would just certify an unbalanced day.
    var coverageWeight: Double {
        switch self {
        case .business: 0.8
        case .body: 1.1
        case .mind: 1.0
        case .relationships: 1.1
        case .recovery: 1.0
        }
    }
}
