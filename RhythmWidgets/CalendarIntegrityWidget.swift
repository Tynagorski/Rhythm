import WidgetKit
import SwiftUI

/// The nag, on the home screen. It is deliberately the plainest widget in the
/// bundle: one number, and it turns red when you have let it slide.
struct CalendarIntegrityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.calendarIntegrity, provider: RhythmTimelineProvider()) { entry in
            CalendarIntegrityView(snapshot: entry.snapshot)
                .containerBackground(Palette.canvas, for: .widget)
        }
        .configurationDisplayName("Calendar integrity")
        .description("How long since you last reviewed the week ahead.")
        .supportedFamilies([.systemSmall])
    }
}

struct CalendarIntegrityView: View {
    var snapshot: WidgetSnapshot

    private var days: Int? { snapshot.daysSinceCalendarReview }

    private var tint: Color {
        guard let days else { return Palette.critical }
        let over = days - snapshot.calendarReviewIntervalDays
        if over >= 2 { return Palette.critical }
        if over >= 0 { return Palette.caution }
        return Palette.positive
    }

    private var caption: String {
        guard let days else { return "never reviewed" }
        switch days {
        case 0: return "reviewed today"
        case 1: return "day since review"
        default: return "days since review"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Calendar", systemImage: snapshot.calendarIsStale
                  ? "calendar.badge.exclamationmark"
                  : "calendar.badge.checkmark")
                .font(.rhythmLabel)
                .foregroundStyle(tint)

            Spacer(minLength: 0)

            Text(days.map(String.init) ?? "—")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())

            Text(caption)
                .font(.rhythmLabel)
                .foregroundStyle(Palette.inkSecondary)

            if snapshot.calendarIsStale {
                Text("Tap to review")
                    .font(.rhythmLabel)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.url(for: .calendarReview))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calendar integrity")
        .accessibilityValue(days.map { "\($0) \(caption)" } ?? "Never reviewed")
    }
}

#Preview(as: .systemSmall) {
    CalendarIntegrityWidget()
} timeline: {
    RhythmEntry(date: .now, snapshot: .placeholder)
}
