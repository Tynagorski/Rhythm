import SwiftUI
import SwiftData

/// Trends, drift, and the honest read on where the week actually went.
struct BalanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences
    @Environment(CalendarService.self) private var calendarService

    @State private var window: Int = 7

    private var logs: [DayLog] {
        DayQueries.recentDayLogs(days: window, context: context)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard
                    breakdownCard
                    trendCard
                    driftCard
                    loadCard
                }
                .padding(16)
            }
            .background(Palette.canvas)
            .navigationTitle("Balance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Window", selection: $window) {
                        Text("7d").tag(7)
                        Text("30d").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
            }
            .refreshable { await coordinator.refreshEverything(preferences: preferences) }
        }
    }

    // MARK: - Cards

    private var scoreCard: some View {
        let result = coordinator.todayResult
        return Card {
            HStack(spacing: 18) {
                RingGauge(
                    progress: Double(result.score) / 100,
                    lineWidth: 12,
                    tint: Palette.score(result.score)
                ) {
                    VStack(spacing: -4) {
                        Text("\(result.score)")
                            .font(.rhythmDisplay)
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Text("today").eyebrowStyle()
                    }
                }
                .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 12) {
                    if let rolling = coordinator.rollingScore {
                        StatTile(value: "\(rolling)", caption: "\(window)-day average", tint: Palette.score(rolling))
                    }
                    StatTile(
                        value: "\(result.coveredDomains.count)/5",
                        caption: "domains touched",
                        tint: result.coveredDomains.count >= 3 ? Palette.positive : Palette.caution
                    )
                    StatTile(
                        value: "\(coordinator.shutdownStreak)",
                        caption: "shutdown streak",
                        tint: Palette.recovery,
                        symbol: "flame.fill"
                    )
                }
            }
        }
    }

    private var breakdownCard: some View {
        let result = coordinator.todayResult
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("What the score is made of", subtitle: result.headline)

                BreakdownBar(title: "Execution", value: result.execution, tint: Palette.business,
                             note: "Weighted completion of what you committed to.")
                BreakdownBar(title: "Rituals", value: result.rituals, tint: Palette.body,
                             note: "Kept versus due today. Deliberate skips do not count against you.")
                BreakdownBar(title: "Coverage", value: result.coverage, tint: Palette.mind,
                             note: "How many parts of your life the day touched.")
                BreakdownBar(title: "Protection", value: result.protection, tint: Palette.recovery,
                             note: "Boundaries held, meeting load, room left to think.")
            }
        }
    }

    private var trendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Trend", subtitle: "Last \(window) days")
                if logs.isEmpty {
                    Text("No history yet. It starts building the first time you close out a day.")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkSecondary)
                } else {
                    ScoreTrendChart(logs: logs)
                        .frame(height: 132)
                }
            }
        }
    }

    private var driftCard: some View {
        let drift = coordinator.drift
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Drift", subtitle: "Days since each domain last got anything")

                ForEach(Domain.allCases) { domain in
                    let days = drift.staleness(domain)
                    HStack(spacing: 10) {
                        Image(systemName: domain.symbol)
                            .font(.caption)
                            .foregroundStyle(domain.tint)
                            .frame(width: 18)
                        Text(domain.title)
                            .font(.rhythmBody)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 104, alignment: .leading)
                        DomainBar(
                            domain: domain,
                            // Full bar is fresh; it empties as the domain goes stale.
                            progress: 1 - min(1, Double(days) / Double(drift.windowDays))
                        )
                        Text(days == 0 ? "today" : "\(days)d")
                            .font(.rhythmLabel)
                            .foregroundStyle(days >= 3 ? Palette.critical : Palette.inkTertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                if let worst = drift.worst {
                    Label(
                        "\(worst.title) has been starved for \(drift.staleness(worst)) days. One fifteen-minute block tomorrow resets it.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.rhythmCaption)
                    .foregroundStyle(Palette.caution)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var loadCard: some View {
        let totalLoad = logs.reduce(0) { $0 + $1.loadMinutes }
        let afterHours = logs.reduce(0) { $0 + $1.afterHoursMinutes }
        let shutdowns = logs.filter(\.didShutDown).count
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Load", subtitle: "What the calendar took")
                HStack(spacing: 12) {
                    StatTile(value: totalLoad.durationLabel, caption: "in meetings")
                    StatTile(
                        value: afterHours.durationLabel,
                        caption: "after hours",
                        tint: afterHours > 0 ? Palette.critical : Palette.positive
                    )
                    StatTile(value: "\(shutdowns)/\(max(1, logs.count))", caption: "days closed out")
                }

                if afterHours > 120 {
                    Text("More than two hours of your \(window)-day window landed outside the boundary you set. That is where the balance is going.")
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct BreakdownBar: View {
    var title: String
    var value: Int
    var tint: Color
    var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.rhythmHeadline).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(value)")
                    .font(.rhythmMetricSmall)
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.hairline)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, geo.size.width * Double(value) / 100))
                        .animation(.snappy, value: value)
                }
            }
            .frame(height: 8)
            Text(note).font(.rhythmLabel).foregroundStyle(Palette.inkTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(value) out of 100")
    }
}
