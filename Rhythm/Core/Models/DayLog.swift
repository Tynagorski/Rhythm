import Foundation
import SwiftData

/// One row per day, written by the shutdown ritual and the balance engine.
/// Keeping the computed score on disk lets trends survive changes to the
/// scoring formula and lets widgets read history without recomputing.
@Model
final class DayLog {
    @Attribute(.unique) var day: Date
    var balanceScore: Int
    var executionScore: Int
    var recoveryScore: Int
    var loadMinutes: Int
    var afterHoursMinutes: Int
    /// Domains that received at least one completed priority or ritual.
    var coveredDomainsRaw: [String]
    var shutdownCompletedAt: Date?
    var energy: Int?
    var note: String

    init(
        day: Date,
        balanceScore: Int = 0,
        executionScore: Int = 0,
        recoveryScore: Int = 0,
        loadMinutes: Int = 0,
        afterHoursMinutes: Int = 0,
        coveredDomains: [Domain] = [],
        shutdownCompletedAt: Date? = nil,
        energy: Int? = nil,
        note: String = ""
    ) {
        self.day = Calendar.current.startOfDay(for: day)
        self.balanceScore = balanceScore
        self.executionScore = executionScore
        self.recoveryScore = recoveryScore
        self.loadMinutes = loadMinutes
        self.afterHoursMinutes = afterHoursMinutes
        self.coveredDomainsRaw = coveredDomains.map(\.rawValue)
        self.shutdownCompletedAt = shutdownCompletedAt
        self.energy = energy
        self.note = note
    }

    var coveredDomains: Set<Domain> {
        get { Set(coveredDomainsRaw.compactMap(Domain.init(rawValue:))) }
        set { coveredDomainsRaw = newValue.map(\.rawValue).sorted() }
    }

    var didShutDown: Bool { shutdownCompletedAt != nil }
}

/// A completed pass over the upcoming calendar. Rhythm nags until one of these
/// is fresh, which is the whole point of the calendar-integrity feature.
@Model
final class CalendarReview {
    @Attribute(.unique) var id: UUID
    var reviewedAt: Date
    var daysAhead: Int
    var eventsScanned: Int
    var issuesFound: Int
    var issuesResolved: Int

    init(
        id: UUID = UUID(),
        reviewedAt: Date = Date(),
        daysAhead: Int = 7,
        eventsScanned: Int = 0,
        issuesFound: Int = 0,
        issuesResolved: Int = 0
    ) {
        self.id = id
        self.reviewedAt = reviewedAt
        self.daysAhead = daysAhead
        self.eventsScanned = eventsScanned
        self.issuesFound = issuesFound
        self.issuesResolved = issuesResolved
    }
}
