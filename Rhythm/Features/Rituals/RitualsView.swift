import SwiftUI
import SwiftData

/// The habit surface. Rituals are grouped by domain rather than listed flat, so
/// a starved domain is visible before it becomes a pattern.
struct RitualsView: View {
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    @Query(filter: #Predicate<Ritual> { $0.isArchived == false },
           sort: [SortDescriptor(\Ritual.sortIndex), SortDescriptor(\Ritual.createdAt)])
    private var rituals: [Ritual]

    @State private var editing: Ritual?
    @State private var showingNew = false

    private var weekDays: [Date] { Calendar.current.daysOfWeek(containing: Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if rituals.isEmpty {
                        Card {
                            EmptyPrompt(
                                symbol: "repeat.circle",
                                title: "No rituals yet",
                                message: "Rituals are the part of the week that does not depend on how the week goes.",
                                actionTitle: "Add your first"
                            ) { showingNew = true }
                        }
                    } else {
                        weekGrid
                        ForEach(Domain.allCases) { domain in
                            let items = rituals.filter { $0.domain == domain }
                            if !items.isEmpty {
                                domainCard(domain: domain, rituals: items)
                            }
                        }
                        missingDomainsCard
                    }
                }
                .padding(16)
            }
            .background(Palette.canvas)
            .navigationTitle("Rituals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a ritual")
                }
            }
            .sheet(isPresented: $showingNew) { RitualEditor() }
            .sheet(item: $editing) { RitualEditor(existing: $0) }
        }
    }

    // MARK: - Week grid

    private var weekGrid: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("This week", subtitle: "Kept, skipped, missed")

                HStack(spacing: 0) {
                    Text("").frame(width: 108, alignment: .leading)
                    ForEach(weekDays, id: \.self) { day in
                        Text(day.weekdayInitial)
                            .font(.rhythmLabel)
                            .foregroundStyle(day.isToday ? Palette.ink : Palette.inkTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(rituals) { ritual in
                    HStack(spacing: 0) {
                        Text(ritual.name)
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 108, alignment: .leading)

                        ForEach(weekDays, id: \.self) { day in
                            RitualDot(ritual: ritual, day: day) { toggle(ritual, on: day) }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func domainCard(domain: Domain, rituals items: [Ritual]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(domain.title) {
                    Image(systemName: domain.symbol).foregroundStyle(domain.tint)
                }

                ForEach(items) { ritual in
                    let adherence = StreakEngine.weeklyAdherence(for: ritual)
                    Button { editing = ritual } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(ritual.name)
                                    .font(.rhythmHeadline)
                                    .foregroundStyle(Palette.ink)
                                HStack(spacing: 8) {
                                    Text(ritual.cadence == .timesPerWeek
                                         ? "\(ritual.targetPerWeek)× a week"
                                         : ritual.cadence.title)
                                    Text("·")
                                    Text(ritual.anchor.timeLabel)
                                    if !ritual.remindersEnabled {
                                        Image(systemName: "bell.slash")
                                    }
                                }
                                .font(.rhythmLabel)
                                .foregroundStyle(Palette.inkTertiary)
                            }
                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(adherence.kept)/\(adherence.target)")
                                    .font(.rhythmMetricSmall)
                                    .foregroundStyle(adherence.kept >= adherence.target ? Palette.positive : Palette.ink)
                                let streak = StreakEngine.streak(for: ritual)
                                if streak > 1 {
                                    Label("\(streak)", systemImage: "flame.fill")
                                        .font(.rhythmLabel)
                                        .foregroundStyle(Palette.caution)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") { editing = ritual }
                        Button("Archive", role: .destructive) { archive(ritual) }
                    }
                }
            }
        }
    }

    /// Names the domains with no ritual at all — the most common reason a
    /// balance score stays capped.
    private var missingDomainsCard: some View {
        let covered = Set(rituals.map(\.domain))
        let missing = Domain.allCases.filter { !covered.contains($0) }
        return Group {
            if !missing.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Uncovered")
                        Text("No ritual is protecting \(missing.map(\.title).joined(separator: ", ")). Balance is capped until something does.")
                            .font(.rhythmBody)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ForEach(missing) { domain in
                                DomainChip(domain: domain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mutations

    private func toggle(_ ritual: Ritual, on day: Date) {
        guard day <= Date() else { return }
        withAnimation(.snappy) { RitualMutator.toggle(ritualID: ritual.id, on: day) }
        coordinator.refreshScoreOnly(preferences: preferences)
    }

    private func archive(_ ritual: Ritual) {
        withAnimation { ritual.isArchived = true }
        try? context.save()
        Task { await coordinator.rescheduleNotifications(preferences: preferences) }
    }
}

/// One cell of the week grid. Future days render as an outline and do not
/// respond — you cannot keep a ritual that has not happened yet.
struct RitualDot: View {
    var ritual: Ritual
    var day: Date
    var onTap: () -> Void

    private var isFuture: Bool { day.startOfDay > Date().startOfDay }
    private var isScheduled: Bool { ritual.isScheduled(on: day) }
    private var entry: RitualEntry? { DayQueries.entry(for: ritual, on: day) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let entry {
                    Circle()
                        .fill(entry.isSkip ? Palette.inkTertiary.opacity(0.35) : ritual.domain.tint)
                    if entry.isSkip {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                    }
                } else if isScheduled && !isFuture {
                    Circle().strokeBorder(Palette.critical.opacity(0.45), lineWidth: 1.5)
                } else {
                    Circle().strokeBorder(Palette.hairline, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(ritual.name), \(day.relativeDayLabel)")
        .accessibilityValue(entry == nil ? (isScheduled && !isFuture ? "Missed" : "Not scheduled") : (entry!.isSkip ? "Skipped" : "Kept"))
    }
}
