import SwiftUI
import SwiftData

/// The week at a glance: what you have committed to, what the calendar has
/// already taken, and where the empty days are.
struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(CalendarService.self) private var calendarService
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    @State private var selectedDay: Date = Date().startOfDay
    @State private var showingEditor = false
    @State private var editorTier: PriorityTier = .keystone

    private var days: [Date] {
        (0..<14).map { Date().startOfDay.adding(days: $0) }
    }

    private var priorities: [Priority] {
        DayQueries.priorities(on: selectedDay, context: context)
    }

    private var agenda: DayAgenda? {
        calendarService.agendas.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDay) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayStrip
                ScrollView {
                    VStack(spacing: 16) {
                        loadCard
                        prioritiesCard
                        if let agenda, !agenda.events.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader("On the calendar")
                                    AgendaStrip(agenda: agenda, limit: 12)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Palette.canvas)
            }
            .background(Palette.canvas)
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTier = priorities.contains { $0.tier == .keystone } ? .momentum : .keystone
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a priority to this day")
                }
            }
            .sheet(isPresented: $showingEditor) {
                PriorityEditor(day: selectedDay, tier: editorTier)
            }
            .refreshable { await coordinator.refreshEverything(preferences: preferences) }
        }
    }

    // MARK: - Day strip

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayChip(
                        day: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDay),
                        load: loadLevel(for: day),
                        plannedCount: DayQueries.priorities(on: day, context: context).count
                    ) {
                        withAnimation(.snappy) { selectedDay = day }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }

    /// 0 = clear, 1 = normal, 2 = heavy. Derived from meeting minutes against
    /// the user's own workday length, not a fixed hour count.
    private func loadLevel(for day: Date) -> Int {
        guard let agenda = calendarService.agendas.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) }) else {
            return 0
        }
        let workday = Double(max(60, preferences.workdayEndMinutes - preferences.workdayStartMinutes))
        let ratio = Double(agenda.meetingMinutes) / workday
        switch ratio {
        case ..<0.25: return 0
        case 0.25..<0.6: return 1
        default: return 2
        }
    }

    // MARK: - Cards

    private var loadCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(selectedDay.relativeDayLabel,
                              subtitle: selectedDay.formatted(.dateTime.weekday(.wide).month().day()))

                if let agenda {
                    HStack(spacing: 12) {
                        StatTile(value: agenda.meetingMinutes.durationLabel, caption: "booked")
                        StatTile(
                            value: agenda.longestFreeBlockMinutes.durationLabel,
                            caption: "clear block",
                            tint: agenda.longestFreeBlockMinutes >= 90 ? Palette.positive : Palette.caution
                        )
                        StatTile(value: "\(agenda.events.count)", caption: "events")
                    }

                    if !agenda.issues.isEmpty {
                        ForEach(agenda.issues.prefix(3)) { issue in
                            Label(issue.detail, systemImage: issue.kind.symbol)
                                .font(.rhythmCaption)
                                .foregroundStyle(issue.kind.isSevere ? Palette.critical : Palette.caution)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if !calendarService.hasAccess {
                    CalendarAccessPrompt()
                } else {
                    Text("Nothing scheduled.")
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }

    private var prioritiesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Committed", subtitle: "\(priorities.filter(\.isDone).count) of \(priorities.count) done")

                if priorities.isEmpty {
                    EmptyPrompt(
                        symbol: "list.bullet.rectangle",
                        title: "Nothing committed",
                        message: selectedDay.isToday
                            ? "Name the keystone and the day has a spine."
                            : "Decide now and future-you inherits a plan instead of a pile.",
                        actionTitle: "Add the keystone"
                    ) {
                        editorTier = .keystone
                        showingEditor = true
                    }
                } else {
                    ForEach(PriorityTier.allCases, id: \.self) { tier in
                        let items = priorities.filter { $0.tier == tier }
                        if !items.isEmpty {
                            Text(tier.title).eyebrowStyle()
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

struct DayChip: View {
    var day: Date
    var isSelected: Bool
    /// 0 clear, 1 normal, 2 heavy.
    var load: Int
    var plannedCount: Int
    var onTap: () -> Void

    private var loadColor: Color {
        switch load {
        case 0: Palette.positive
        case 1: Palette.caution
        default: Palette.critical
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(day.weekdayInitial)
                    .font(.rhythmLabel)
                    .foregroundStyle(isSelected ? .white : Palette.inkTertiary)
                Text(day.formatted(.dateTime.day()))
                    .font(.rhythmMetricSmall)
                    .foregroundStyle(isSelected ? .white : Palette.ink)
                HStack(spacing: 3) {
                    Circle().fill(loadColor).frame(width: 5, height: 5)
                    if plannedCount > 0 {
                        Text("\(plannedCount)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : Palette.inkTertiary)
                    }
                }
            }
            .frame(width: 46, height: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Palette.business : Palette.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(day.isToday && !isSelected ? Palette.business : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue("\(plannedCount) planned")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
