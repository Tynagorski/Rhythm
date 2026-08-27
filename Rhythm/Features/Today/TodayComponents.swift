import UIKit
import SwiftUI
import SwiftData

struct PriorityRow: View {
    @Bindable var priority: Priority
    var prominent: Bool = false
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: priority.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: prominent ? 26 : 22))
                    .foregroundStyle(priority.isDone ? Palette.positive : Palette.inkTertiary)
                    .symbolEffect(.bounce, value: priority.isDone)

                VStack(alignment: .leading, spacing: 4) {
                    Text(priority.title)
                        .font(prominent ? .rhythmTitle : .rhythmHeadline)
                        .foregroundStyle(priority.isDone ? Palette.inkTertiary : Palette.ink)
                        .strikethrough(priority.isDone, color: Palette.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !priority.details.isEmpty {
                        Text(priority.details)
                            .font(.rhythmBody)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        DomainChip(domain: priority.domain)
                        if priority.estimateMinutes > 0 {
                            Label(priority.estimateMinutes.durationLabel, systemImage: "clock")
                                .font(.rhythmLabel)
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(priority.isDone ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(priority.isDone ? "Double tap to mark as not done" : "Double tap to complete")
    }
}

/// The calendar-integrity nag, in-app. Escalates its tone with staleness so a
/// glance tells you how overdue you are.
struct CalendarStalenessBanner: View {
    @Environment(AppPreferences.self) private var preferences
    var action: () -> Void

    private var days: Int? { preferences.daysSinceCalendarReview }

    private var tint: Color {
        guard let days else { return Palette.caution }
        let over = days - preferences.calendarReviewIntervalDays
        return over >= 2 ? Palette.critical : Palette.caution
    }

    private var title: String {
        guard let days else { return "Review your calendar" }
        switch days {
        case 0: return "Reviewed today"
        case 1: return "Reviewed yesterday"
        default: return "\(days) days since your last calendar review"
        }
    }

    private var message: String {
        guard days != nil else {
            return "Rhythm can only be as accurate as your calendar. Take five minutes."
        }
        return "Confirm next week before someone else fills it in for you."
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rhythmHeadline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(message)
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(14)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CalendarAccessPrompt: View {
    @Environment(CalendarService.self) private var calendarService
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(calendarService.isDenied
                 ? "Calendar access is off. Rhythm cannot see your load or spot conflicts without it."
                 : "Connect your calendar and Rhythm will flag conflicts, unanswered invites and days with no room to think.")
                .font(.rhythmBody)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if calendarService.isDenied {
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .font(.rhythmCaption)
            } else {
                Button("Connect calendar") {
                    Task {
                        await calendarService.requestAccess()
                        await coordinator.refreshEverything(preferences: preferences)
                    }
                }
                .font(.rhythmCaption)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Compact timeline for one day: what is next, and how loaded the day is.
struct AgendaStrip: View {
    var agenda: DayAgenda
    var limit: Int = 4

    private var upcoming: [AgendaEvent] {
        let now = Date()
        let future = agenda.events.filter { !$0.isAllDay && $0.end > now }
        return Array((future.isEmpty ? agenda.events.filter { !$0.isAllDay } : future).prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if upcoming.isEmpty {
                Text("Clear. Protect it before something else does.")
                    .font(.rhythmBody)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                ForEach(upcoming) { event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(event.start.timeLabel)
                                .font(.rhythmCaption)
                                .foregroundStyle(Palette.ink)
                            Text(event.durationMinutes.durationLabel)
                                .font(.rhythmLabel)
                                .foregroundStyle(Palette.inkTertiary)
                        }
                        .frame(width: 62, alignment: .trailing)

                        Capsule()
                            .fill(event.needsResponse ? Palette.caution : Palette.business)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.rhythmBody)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                            if event.needsResponse {
                                Text("Awaiting your response")
                                    .font(.rhythmLabel)
                                    .foregroundStyle(Palette.caution)
                            } else if event.attendeeCount > 1 {
                                Text("\(event.attendeeCount) people")
                                    .font(.rhythmLabel)
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Divider().overlay(Palette.hairline)

            HStack(spacing: 12) {
                StatTile(value: agenda.meetingMinutes.durationLabel, caption: "booked")
                StatTile(
                    value: agenda.longestFreeBlockMinutes.durationLabel,
                    caption: "longest clear block",
                    tint: agenda.longestFreeBlockMinutes >= 90 ? Palette.positive : Palette.caution
                )
                if agenda.afterHoursMinutes > 0 {
                    StatTile(
                        value: agenda.afterHoursMinutes.durationLabel,
                        caption: "after hours",
                        tint: Palette.critical
                    )
                }
            }
        }
    }
}

/// The horizontally scrolling ritual check-off used on the Today screen.
struct TodayRitualRow: View {
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    @Query(filter: #Predicate<Ritual> { $0.isArchived == false },
           sort: [SortDescriptor(\Ritual.sortIndex)])
    private var rituals: [Ritual]

    private var due: [Ritual] {
        DayQueries.ritualsDue(on: Date(), context: context)
    }

    var body: some View {
        if due.isEmpty {
            Text(rituals.isEmpty
                 ? "No rituals yet. Add a few in the Rituals tab and Rhythm will keep score."
                 : "Nothing due today. Rest is part of the plan.")
                .font(.rhythmBody)
                .foregroundStyle(Palette.inkTertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(due) { ritual in
                        RitualPill(ritual: ritual, isDone: DayQueries.isCompleted(ritual, on: Date())) {
                            toggle(ritual)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func toggle(_ ritual: Ritual) {
        withAnimation(.snappy) {
            RitualMutator.toggle(ritualID: ritual.id)
        }
        coordinator.refreshScoreOnly(preferences: preferences)
    }
}

struct RitualPill: View {
    var ritual: Ritual
    var isDone: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: isDone ? "checkmark.circle.fill" : ritual.domain.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone ? .white : ritual.domain.tint)
                Text(ritual.name)
                    .font(.rhythmLabel)
                    .foregroundStyle(isDone ? .white : Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 78)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isDone ? ritual.domain.tint : ritual.domain.tint.opacity(0.12))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ritual.name)
        .accessibilityValue(isDone ? "Kept" : "Not yet")
        .accessibilityAddTraits(.isButton)
    }
}
