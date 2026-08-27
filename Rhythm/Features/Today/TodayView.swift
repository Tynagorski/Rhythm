import SwiftUI
import SwiftData

struct TodayView: View {
    var onOpenShutdown: () -> Void
    var onOpenCalendarReview: () -> Void

    @Environment(AppPreferences.self) private var preferences
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.modelContext) private var context

    @Query private var allPriorities: [Priority]
    @State private var showingAddPriority = false
    @State private var addTier: PriorityTier = .keystone

    init(onOpenShutdown: @escaping () -> Void, onOpenCalendarReview: @escaping () -> Void) {
        self.onOpenShutdown = onOpenShutdown
        self.onOpenCalendarReview = onOpenCalendarReview
        let start = Date().startOfDay
        _allPriorities = Query(
            filter: #Predicate<Priority> { $0.day == start },
            sort: [SortDescriptor(\Priority.sortIndex), SortDescriptor(\Priority.createdAt)]
        )
    }

    private var keystone: Priority? { allPriorities.first { $0.tier == .keystone } }
    private var momentum: [Priority] { allPriorities.filter { $0.tier == .momentum } }
    private var maintenance: [Priority] { allPriorities.filter { $0.tier == .maintenance } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if preferences.calendarIsStale {
                        CalendarStalenessBanner(action: onOpenCalendarReview)
                    }

                    keystoneCard
                    agendaCard
                    priorityList(title: "Momentum", tier: .momentum, items: momentum)
                    ritualStrip
                    priorityList(title: "Maintenance", tier: .maintenance, items: maintenance)
                    shutdownCard
                }
                .padding(16)
            }
            .background(Palette.canvas)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTier = keystone == nil ? .keystone : .momentum
                        showingAddPriority = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a priority")
                }
            }
            .sheet(isPresented: $showingAddPriority) {
                PriorityEditor(day: Date(), tier: addTier)
            }
            .refreshable { await coordinator.refreshEverything(preferences: preferences) }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<5: return "Still up"
        case 5..<12: return "Good morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Wind down"
        }
    }

    // MARK: - Header

    private var header: some View {
        Card {
            HStack(spacing: 16) {
                RingGauge(
                    progress: Double(coordinator.todayResult.score) / 100,
                    lineWidth: 9,
                    tint: Palette.score(coordinator.todayResult.score)
                ) {
                    VStack(spacing: -2) {
                        Text("\(coordinator.todayResult.score)")
                            .font(.rhythmMetric)
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Text("balance").eyebrowStyle()
                    }
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                        .eyebrowStyle()
                    Text(coordinator.todayResult.headline)
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        if let rolling = coordinator.rollingScore {
                            StatTile(value: "\(rolling)", caption: "7-day", tint: Palette.score(rolling))
                        }
                        if coordinator.shutdownStreak > 0 {
                            StatTile(
                                value: "\(coordinator.shutdownStreak)",
                                caption: "shutdowns",
                                tint: Palette.recovery,
                                symbol: "flame.fill"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Keystone

    private var keystoneCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Keystone", subtitle: PriorityTier.keystone.subtitle)

                if let keystone {
                    PriorityRow(priority: keystone, prominent: true) { toggle(keystone) }
                } else {
                    EmptyPrompt(
                        symbol: "target",
                        title: "No keystone yet",
                        message: "One thing. If only this gets done, today still counted.",
                        actionTitle: "Set the keystone"
                    ) {
                        addTier = .keystone
                        showingAddPriority = true
                    }
                }
            }
        }
    }

    // MARK: - Agenda

    private var agendaCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Next up") {
                    Button("Review week", action: onOpenCalendarReview)
                        .font(.rhythmCaption)
                }

                if !calendarService.hasAccess {
                    CalendarAccessPrompt()
                } else if let agenda = calendarService.today {
                    AgendaStrip(agenda: agenda)
                } else {
                    Text("Nothing on the calendar today.")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }

    // MARK: - Priorities

    private func priorityList(title: String, tier: PriorityTier, items: [Priority]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title, subtitle: limitLabel(for: tier, count: items.count)) {
                    Button {
                        addTier = tier
                        showingAddPriority = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .disabled(isAtLimit(tier: tier, count: items.count))
                    .accessibilityLabel("Add \(title.lowercased()) task")
                }

                if items.isEmpty {
                    Text(tier == .momentum
                         ? "Up to three. Choose the ones that move a number."
                         : "The small stuff. Batch it, do not let it lead.")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkTertiary)
                } else {
                    ForEach(items) { item in
                        PriorityRow(priority: item) { toggle(item) }
                            .contextMenu {
                                Button("Move to tomorrow") { move(item, days: 1) }
                                Button("Delete", role: .destructive) { delete(item) }
                            }
                    }
                }
            }
        }
    }

    private func limitLabel(for tier: PriorityTier, count: Int) -> String? {
        guard let limit = tier.dailyLimit else { return nil }
        return "\(count) of \(limit)"
    }

    private func isAtLimit(tier: PriorityTier, count: Int) -> Bool {
        guard let limit = tier.dailyLimit else { return false }
        return count >= limit
    }

    // MARK: - Rituals

    private var ritualStrip: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Rituals due", subtitle: "Tap to keep")
                TodayRitualRow()
            }
        }
    }

    // MARK: - Shutdown

    private var shutdownCard: some View {
        let log = DayQueries.dayLog(for: Date(), context: context)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Close the day")
                if log?.didShutDown == true {
                    Label("Day closed out. Put it down.", systemImage: "checkmark.seal.fill")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.positive)
                } else {
                    Text("Log the day, set tomorrow's keystone, and stop. The shutdown is what makes the rest of this honest.")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkSecondary)
                    Button("Start shutdown", action: onOpenShutdown)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Mutations

    private func toggle(_ priority: Priority) {
        withAnimation(.snappy) { priority.setDone(!priority.isDone) }
        try? context.save()
        coordinator.refreshScoreOnly(preferences: preferences)
    }

    private func move(_ priority: Priority, days: Int) {
        withAnimation { priority.day = priority.day.adding(days: days) }
        try? context.save()
        coordinator.refreshScoreOnly(preferences: preferences)
    }

    private func delete(_ priority: Priority) {
        withAnimation { context.delete(priority) }
        try? context.save()
        coordinator.refreshScoreOnly(preferences: preferences)
    }
}
