import WidgetKit
import SwiftUI

/// The score plus the five domains, so a glance answers "what is missing today"
/// rather than only "how am I doing".
struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.balance, provider: RhythmTimelineProvider()) { entry in
            BalanceWidgetView(snapshot: entry.snapshot)
                .containerBackground(Palette.canvas, for: .widget)
        }
        .configurationDisplayName("Balance")
        .description("Today's balance score and which parts of your life it touched.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: WidgetSnapshot

    var body: some View {
        if family == .systemSmall { small } else { medium }
    }

    private var small: some View {
        VStack(spacing: 6) {
            RingGauge(
                progress: Double(snapshot.score) / 100,
                lineWidth: 8,
                tint: Palette.score(snapshot.score)
            ) {
                VStack(spacing: -2) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("balance").eyebrowStyle()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            domainDots
        }
        .widgetURL(DeepLink.url(for: .balance))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            RingGauge(
                progress: Double(snapshot.score) / 100,
                lineWidth: 8,
                tint: Palette.score(snapshot.score)
            ) {
                VStack(spacing: -2) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("balance").eyebrowStyle()
                }
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.headline)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                ForEach(Domain.allCases) { domain in
                    HStack(spacing: 6) {
                        Image(systemName: domain.symbol)
                            .font(.system(size: 9))
                            .foregroundStyle(snapshot.coveredDomains.contains(domain) ? domain.tint : Palette.inkTertiary)
                            .frame(width: 12)
                        Text(domain.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(snapshot.coveredDomains.contains(domain) ? Palette.ink : Palette.inkTertiary)
                        Spacer(minLength: 0)
                        Image(systemName: snapshot.coveredDomains.contains(domain) ? "checkmark" : "minus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(snapshot.coveredDomains.contains(domain) ? Palette.positive : Palette.inkTertiary)
                    }
                }
            }
        }
        .widgetURL(DeepLink.url(for: .balance))
    }

    /// Coverage as five dots. A filled dot means the domain got something today;
    /// the SF Symbol inside each dot keeps it readable without colour.
    private var domainDots: some View {
        HStack(spacing: 5) {
            ForEach(Domain.allCases) { domain in
                let covered = snapshot.coveredDomains.contains(domain)
                Image(systemName: domain.symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(covered ? .white : Palette.inkTertiary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(covered ? domain.tint : Palette.hairline))
                    .accessibilityLabel(domain.title)
                    .accessibilityValue(covered ? "Touched" : "Untouched")
            }
        }
    }
}

#Preview(as: .systemMedium) {
    BalanceWidget()
} timeline: {
    RhythmEntry(date: .now, snapshot: .placeholder)
}
