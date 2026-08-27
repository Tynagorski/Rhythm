import WidgetKit
import SwiftUI
import AppIntents

/// A full check-off grid on the home screen. The whole point is that keeping a
/// ritual costs one tap and no context switch.
struct RitualsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.rituals, provider: RhythmTimelineProvider()) { entry in
            RitualsWidgetView(snapshot: entry.snapshot)
                .containerBackground(Palette.canvas, for: .widget)
        }
        .configurationDisplayName("Rituals")
        .description("Tick today's rituals without opening the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RitualsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: WidgetSnapshot

    private var limit: Int { family == .systemLarge ? 8 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rituals").eyebrowStyle()
                Spacer()
                Text("\(snapshot.ritualsKept) of \(snapshot.rituals.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.ritualsKept == snapshot.rituals.count && !snapshot.rituals.isEmpty
                                     ? Palette.positive : Palette.inkSecondary)
            }

            if snapshot.rituals.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing due today.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.rituals.prefix(limit)) { ritual in
                    Button(intent: ToggleRitualIntent(ritualID: ritual.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: ritual.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(ritual.isDone ? ritual.domain.tint : Palette.inkTertiary)
                            Text(ritual.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(ritual.isDone ? Palette.inkTertiary : Palette.ink)
                                .strikethrough(ritual.isDone, color: Palette.inkTertiary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: ritual.domain.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(ritual.domain.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ritual.name)
                    .accessibilityValue(ritual.isDone ? "Kept" : "Not yet")
                }
                Spacer(minLength: 0)

                if let drift = snapshot.driftDomain, snapshot.driftDays >= 3 {
                    Label("\(drift.title) starved \(snapshot.driftDays)d", systemImage: "exclamationmark.triangle.fill")
                        .font(.rhythmLabel)
                        .foregroundStyle(Palette.caution)
                }
            }
        }
        .widgetURL(DeepLink.url(for: .rituals))
    }
}

#Preview(as: .systemLarge) {
    RitualsWidget()
} timeline: {
    RhythmEntry(date: .now, snapshot: .placeholder)
}
