import WidgetKit
import SwiftUI

/// Lock Screen and StandBy. These are glance surfaces, so each family shows
/// exactly one idea: the score, the keystone, or how stale the calendar is.
struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.lockScreen, provider: RhythmTimelineProvider()) { entry in
            LockScreenWidgetView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Rhythm at a glance")
        .description("Balance, keystone, or calendar staleness on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    /// Accessory widgets render in a single tint, so the ring cannot carry the
    /// score band — the number does.
    private var circular: some View {
        Gauge(value: Double(snapshot.score), in: 0...100) {
            Image(systemName: "metronome.fill")
        } currentValueLabel: {
            Text("\(snapshot.score)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(DeepLink.url(for: .balance))
        .accessibilityLabel("Balance score")
        .accessibilityValue("\(snapshot.score) out of 100")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                Text(headline)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            Text(detail)
                .font(.system(size: 13, weight: .regular))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.url(for: snapshot.calendarIsStale ? .calendarReview : .today))
    }

    private var inline: some View {
        Text(inlineText)
            .widgetURL(DeepLink.url(for: .today))
    }

    /// The Lock Screen gets the most urgent thing, not the prettiest.
    private var headline: String {
        if snapshot.calendarIsStale { return "Calendar needs review" }
        return snapshot.keystone == nil ? "No keystone" : "Keystone"
    }

    private var detail: String {
        if snapshot.calendarIsStale, let days = snapshot.daysSinceCalendarReview {
            return "\(days) days since you last looked at the week ahead."
        }
        if snapshot.calendarIsStale { return "You have not reviewed the week ahead yet." }
        guard let keystone = snapshot.keystone else { return "Name the one thing that makes today count." }
        return keystone.isDone ? "Done — \(keystone.title)" : keystone.title
    }

    private var inlineText: String {
        if snapshot.calendarIsStale, let days = snapshot.daysSinceCalendarReview {
            return "Calendar \(days)d stale"
        }
        return "Balance \(snapshot.score) · \(snapshot.ritualsKept)/\(snapshot.rituals.count) rituals"
    }
}

#Preview(as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    RhythmEntry(date: .now, snapshot: .placeholder)
}
