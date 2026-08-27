import WidgetKit
import SwiftUI
import AppIntents

/// The default widget: the keystone, the balance ring, and — at medium — a row
/// of rituals you can tick without opening the app.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.today, provider: RhythmTimelineProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(Palette.canvas, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your keystone, your balance, and the rituals still due.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemLarge: large
        default: medium
        }
    }

    // MARK: - Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keystone").eyebrowStyle()
                Spacer()
                RingGauge(
                    progress: Double(snapshot.score) / 100,
                    lineWidth: 4,
                    tint: Palette.score(snapshot.score)
                ) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 30, height: 30)
            }

            if let keystone = snapshot.keystone {
                Text(keystone.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(keystone.isDone ? Palette.inkTertiary : Palette.ink)
                    .strikethrough(keystone.isDone, color: Palette.inkTertiary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            } else {
                Text("No keystone set")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "repeat")
                Text("\(snapshot.ritualsKept)/\(snapshot.rituals.count) rituals")
            }
            .font(.rhythmLabel)
            .foregroundStyle(Palette.inkSecondary)
        }
        .widgetURL(DeepLink.url(for: .today))
    }

    // MARK: - Medium

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Keystone").eyebrowStyle()

                if let keystone = snapshot.keystone {
                    HStack(alignment: .top, spacing: 8) {
                        Button(intent: TogglePriorityIntent(priorityID: keystone.id)) {
                            Image(systemName: keystone.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(keystone.isDone ? Palette.positive : Palette.inkTertiary)
                        }
                        .buttonStyle(.plain)

                        Text(keystone.title)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(keystone.isDone ? Palette.inkTertiary : Palette.ink)
                            .strikethrough(keystone.isDone, color: Palette.inkTertiary)
                            .lineLimit(2)
                    }
                } else {
                    Text("No keystone. Name the one thing.")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if snapshot.calendarIsStale {
                    Label(staleLabel, systemImage: "calendar.badge.exclamationmark")
                        .font(.rhythmLabel)
                        .foregroundStyle(Palette.caution)
                        .lineLimit(1)
                }

                RitualStrip(rituals: Array(snapshot.rituals.prefix(4)))
            }

            RingGauge(
                progress: Double(snapshot.score) / 100,
                lineWidth: 7,
                tint: Palette.score(snapshot.score)
            ) {
                VStack(spacing: -2) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("balance").eyebrowStyle()
                }
            }
            .frame(width: 64, height: 64)
        }
        .widgetURL(DeepLink.url(for: .today))
    }

    // MARK: - Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                        .eyebrowStyle()
                    Text(snapshot.headline)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                RingGauge(
                    progress: Double(snapshot.score) / 100,
                    lineWidth: 7,
                    tint: Palette.score(snapshot.score)
                ) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 58, height: 58)
            }

            Divider().overlay(Palette.hairline)

            if let keystone = snapshot.keystone {
                WidgetTaskRow(
                    title: keystone.title,
                    domain: keystone.domain,
                    isDone: keystone.isDone,
                    intent: TogglePriorityIntent(priorityID: keystone.id),
                    prominent: true
                )
            }

            ForEach(snapshot.momentum.prefix(3)) { item in
                WidgetTaskRow(
                    title: item.title,
                    domain: item.domain,
                    isDone: item.isDone,
                    intent: TogglePriorityIntent(priorityID: item.id)
                )
            }

            Spacer(minLength: 0)

            RitualStrip(rituals: Array(snapshot.rituals.prefix(5)))

            if snapshot.calendarIsStale {
                Link(destination: DeepLink.url(for: .calendarReview)) {
                    Label(staleLabel, systemImage: "calendar.badge.exclamationmark")
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.caution)
                }
            }
        }
        .widgetURL(DeepLink.url(for: .today))
    }

    private var staleLabel: String {
        guard let days = snapshot.daysSinceCalendarReview else { return "Calendar never reviewed" }
        return "Calendar \(days)d stale"
    }
}

/// One tappable ritual. Tapping runs an App Intent in the extension, which
/// writes to the shared store and reloads the timeline in place.
struct RitualStrip: View {
    var rituals: [WidgetSnapshot.RitualItem]

    var body: some View {
        if rituals.isEmpty {
            Text("No rituals due")
                .font(.rhythmLabel)
                .foregroundStyle(Palette.inkTertiary)
        } else {
            HStack(spacing: 6) {
                ForEach(rituals) { ritual in
                    Button(intent: ToggleRitualIntent(ritualID: ritual.id)) {
                        Image(systemName: ritual.isDone ? "checkmark" : ritual.domain.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ritual.isDone ? .white : ritual.domain.tint)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(ritual.isDone ? ritual.domain.tint : ritual.domain.tint.opacity(0.16))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ritual.name)
                    .accessibilityValue(ritual.isDone ? "Kept" : "Not yet")
                }
            }
        }
    }
}

struct WidgetTaskRow<I: AppIntent>: View {
    var title: String
    var domain: Domain
    var isDone: Bool
    var intent: I
    var prominent: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(intent: intent) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: prominent ? 18 : 15))
                    .foregroundStyle(isDone ? Palette.positive : Palette.inkTertiary)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(prominent ? .subheadline : .caption, weight: prominent ? .semibold : .regular))
                .foregroundStyle(isDone ? Palette.inkTertiary : Palette.ink)
                .strikethrough(isDone, color: Palette.inkTertiary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    RhythmEntry(date: .now, snapshot: .placeholder)
}
