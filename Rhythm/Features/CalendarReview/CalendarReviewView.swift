import SwiftUI
import UIKit

/// The guided pass over the next seven days. This is the flow every calendar
/// nudge leads to, and finishing it is what resets the staleness clock.
struct CalendarReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarService.self) private var calendarService
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    /// Issues the user has explicitly dealt with in this pass.
    @State private var handled: Set<String> = []
    @State private var isFinishing = false

    private var issues: [CalendarIssue] { calendarService.allIssues }
    private var outstanding: [CalendarIssue] { issues.filter { !handled.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if !calendarService.hasAccess {
                    accessGate
                } else {
                    content
                }
            }
            .background(Palette.canvas)
            .navigationTitle("Calendar review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
            .task {
                if calendarService.hasAccess {
                    await calendarService.refresh(days: 7, preferences: preferences)
                }
            }
        }
    }

    private var accessGate: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(Palette.business)
            Text("Rhythm needs to read your calendar")
                .font(.rhythmTitle)
                .multilineTextAlignment(.center)
            Text("It only reads. Nothing is created, changed or deleted, and nothing leaves your device.")
                .font(.rhythmBody)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            if calendarService.isDenied {
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Allow calendar access") {
                    Task {
                        await calendarService.requestAccess()
                        await calendarService.refresh(days: 7, preferences: preferences)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding(24)
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if calendarService.isLoading {
                        ProgressView("Reading the week ahead")
                            .font(.rhythmCaption)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }

                    if let error = calendarService.lastLoadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.critical)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    summaryCard

                    if issues.isEmpty {
                        Card {
                            EmptyPrompt(
                                symbol: "checkmark.seal.fill",
                                title: "Nothing to fix",
                                message: "Seven days ahead and no conflicts, no unanswered invites, no days without room to think."
                            )
                        }
                    } else {
                        ForEach(CalendarIssue.Kind.allGrouped, id: \.self) { kind in
                            let group = issues.filter { $0.kind == kind }
                            if !group.isEmpty {
                                issueCard(kind: kind, group: group)
                            }
                        }
                    }

                    weekCard
                }
                .padding(16)
            }
            finishBar
        }
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Next 7 days", subtitle: staleLabel)
                HStack(spacing: 12) {
                    StatTile(
                        value: "\(calendarService.agendas.reduce(0) { $0 + $1.events.count })",
                        caption: "events"
                    )
                    StatTile(
                        value: "\(issues.count)",
                        caption: "flagged",
                        tint: issues.isEmpty ? Palette.positive : Palette.caution
                    )
                    StatTile(
                        value: "\(handled.count)",
                        caption: "handled",
                        tint: Palette.positive
                    )
                }
            }
        }
    }

    private var staleLabel: String {
        guard let days = preferences.daysSinceCalendarReview else {
            return "You have not reviewed your calendar in Rhythm yet."
        }
        switch days {
        case 0: return "Last reviewed today."
        case 1: return "Last reviewed yesterday."
        default: return "Last reviewed \(days) days ago."
        }
    }

    private func issueCard(kind: CalendarIssue.Kind, group: [CalendarIssue]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(kind.title, subtitle: Self.guidance(for: kind)) {
                    Image(systemName: kind.symbol)
                        .foregroundStyle(kind.isSevere ? Palette.critical : Palette.caution)
                }

                ForEach(group) { issue in
                    let isHandled = handled.contains(issue.id)
                    Button {
                        withAnimation(.snappy) {
                            if isHandled { handled.remove(issue.id) } else { handled.insert(issue.id) }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isHandled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isHandled ? Palette.positive : Palette.inkTertiary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(issue.detail)
                                    .font(.rhythmBody)
                                    .foregroundStyle(isHandled ? Palette.inkTertiary : Palette.ink)
                                    .strikethrough(isHandled, color: Palette.inkTertiary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(issue.day.relativeDayLabel)
                                    .font(.rhythmLabel)
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                            Spacer(minLength: 0)
                            Button {
                                CalendarLauncher.open(day: issue.day)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundStyle(Palette.business)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(issue.day.relativeDayLabel) in Calendar")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Load ahead")
                ForEach(calendarService.agendas) { agenda in
                    HStack(spacing: 10) {
                        Text(agenda.day.relativeDayLabel)
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 84, alignment: .leading)
                        DomainBar(
                            domain: .business,
                            progress: Double(agenda.meetingMinutes) / Double(max(60, preferences.workdayEndMinutes - preferences.workdayStartMinutes))
                        )
                        Text(agenda.meetingMinutes.durationLabel)
                            .font(.rhythmLabel)
                            .foregroundStyle(Palette.inkTertiary)
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var finishBar: some View {
        VStack(spacing: 8) {
            if !outstanding.isEmpty {
                Text("\(outstanding.count) still open. You can finish anyway — the point is that you looked.")
                    .font(.rhythmLabel)
                    .foregroundStyle(Palette.inkTertiary)
                    .multilineTextAlignment(.center)
            }
            Button {
                finish()
            } label: {
                Label("Mark calendar reviewed", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isFinishing)
        }
        .padding(16)
        .background(Palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    private func finish() {
        isFinishing = true
        Task {
            await coordinator.recordCalendarReview(
                issuesFound: issues.count,
                issuesResolved: handled.count,
                preferences: preferences
            )
            await coordinator.refreshEverything(preferences: preferences)
            dismiss()
        }
    }

    static func guidance(for kind: CalendarIssue.Kind) -> String {
        switch kind {
        case .conflict: "Two things cannot both happen. Decline one now."
        case .unanswered: "An unanswered invite is a decision you are still carrying."
        case .overloaded: "Move one meeting and the day becomes survivable."
        case .afterHours: "Work past your boundary is the leak the score keeps finding."
        case .noBreak: "Block ninety minutes before someone else takes it."
        case .noPersonalTime: "If it is not on the calendar it will not happen."
        case .emptyDay: "An empty workday usually means an out-of-date calendar."
        }
    }
}

extension CalendarIssue.Kind {
    /// Display order for the review flow: worst first.
    static var allGrouped: [CalendarIssue.Kind] {
        [.conflict, .unanswered, .overloaded, .afterHours, .noBreak, .noPersonalTime, .emptyDay]
    }
}

/// Opens Apple Calendar at a given day. `calshow:` takes seconds since the
/// 2001 reference date.
enum CalendarLauncher {
    static func open(day: Date) {
        let seconds = Int(day.timeIntervalSinceReferenceDate)
        guard let url = URL(string: "calshow:\(seconds)") else { return }
        UIApplication.shared.open(url)
    }
}
