import Foundation
import SwiftData

/// How much of the day a task is allowed to claim. The tiers are capped
/// deliberately — one keystone, three momentum tasks — so the plan stays a plan
/// rather than a wish list.
enum PriorityTier: String, CaseIterable, Codable, Sendable {
    case keystone
    case momentum
    case maintenance

    var title: String {
        switch self {
        case .keystone: "Keystone"
        case .momentum: "Momentum"
        case .maintenance: "Maintenance"
        }
    }

    var subtitle: String {
        switch self {
        case .keystone: "The one thing that makes today count"
        case .momentum: "Real progress, not busywork"
        case .maintenance: "Keeps the machine running"
        }
    }

    var symbol: String {
        switch self {
        case .keystone: "target"
        case .momentum: "arrow.up.right"
        case .maintenance: "checkmark.circle"
        }
    }

    /// `nil` means unlimited.
    var dailyLimit: Int? {
        switch self {
        case .keystone: 1
        case .momentum: 3
        case .maintenance: nil
        }
    }

    /// Contribution to the day's execution score.
    var weight: Double {
        switch self {
        case .keystone: 3
        case .momentum: 1.5
        case .maintenance: 0.5
        }
    }
}

@Model
final class Priority {
    /// Stable identity used by widgets and App Intents, which cannot rely on
    /// `PersistentIdentifier` surviving across processes.
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    /// Stored as a raw value: SwiftData handles enums, but raw strings keep the
    /// store readable and migration-proof if a case is ever renamed.
    var tierRaw: String
    var domainRaw: String
    /// Start of the day this belongs to, in the user's calendar.
    var day: Date
    var isDone: Bool
    var completedAt: Date?
    var estimateMinutes: Int
    var sortIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        tier: PriorityTier,
        domain: Domain,
        day: Date,
        estimateMinutes: Int = 30,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.tierRaw = tier.rawValue
        self.domainRaw = domain.rawValue
        self.day = Calendar.current.startOfDay(for: day)
        self.isDone = false
        self.completedAt = nil
        self.estimateMinutes = estimateMinutes
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var tier: PriorityTier {
        get { PriorityTier(rawValue: tierRaw) ?? .maintenance }
        set { tierRaw = newValue.rawValue }
    }

    var domain: Domain {
        get { Domain(rawValue: domainRaw) ?? .business }
        set { domainRaw = newValue.rawValue }
    }

    func setDone(_ done: Bool, at date: Date = Date()) {
        isDone = done
        completedAt = done ? date : nil
    }
}
