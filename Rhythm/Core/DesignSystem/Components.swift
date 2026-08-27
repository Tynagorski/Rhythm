import SwiftUI

/// A rounded surface used for every grouped block in the app.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
    }
}

/// The balance ring. Also used at small sizes in widgets and on the lock screen,
/// so line width and label are both parameterised.
struct RingGauge: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Palette.positive
    var track: Color = Palette.hairline
    /// When nil the ring renders bare, which is what the accessory widgets want.
    var label: AnyView?

    init(progress: Double, lineWidth: CGFloat = 10, tint: Color = Palette.positive, track: Color = Palette.hairline) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.track = track
        self.label = nil
    }

    init<Label: View>(
        progress: Double,
        lineWidth: CGFloat = 10,
        tint: Color = Palette.positive,
        track: Color = Palette.hairline,
        @ViewBuilder label: () -> Label
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.track = track
        self.label = AnyView(label())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.45), value: progress)
            label
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

/// Horizontal bar for a single domain's share of the day.
struct DomainBar: View {
    var domain: Domain
    var progress: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule()
                    .fill(domain.tint)
                    .frame(width: max(height, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(domain.title)
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

struct DomainChip: View {
    var domain: Domain
    var isSelected: Bool = false

    var body: some View {
        Label(domain.title, systemImage: domain.symbol)
            .font(.rhythmCaption)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.white : domain.tint)
            .background(
                Capsule().fill(isSelected ? domain.tint : domain.tint.opacity(0.14))
            )
    }
}

/// Used wherever a list can legitimately be empty — Rhythm treats an empty list
/// as a prompt, never as a failure state.
struct EmptyPrompt: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
            Text(title)
                .font(.rhythmHeadline)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.rhythmBody)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.rhythmCaption)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// A single-line stat used in headers and the balance grid.
struct StatTile: View {
    var value: String
    var caption: String
    var tint: Color = Palette.ink
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).font(.caption).foregroundStyle(tint)
                }
                Text(value)
                    .font(.rhythmMetricSmall)
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            Text(caption)
                .font(.rhythmLabel)
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<Trailing: View>(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).eyebrowStyle()
                if let subtitle {
                    Text(subtitle)
                        .font(.rhythmBody)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}
