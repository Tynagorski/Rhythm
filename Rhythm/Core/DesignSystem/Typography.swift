import SwiftUI

/// A small, deliberate type scale. Numerics use the rounded design so scores and
/// streaks read as data rather than prose.
extension Font {
    static let rhythmDisplay = Font.system(size: 44, weight: .bold, design: .rounded)
    static let rhythmMetric = Font.system(size: 30, weight: .semibold, design: .rounded)
    static let rhythmMetricSmall = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let rhythmTitle = Font.system(.title2, design: .default, weight: .bold)
    static let rhythmHeadline = Font.system(.headline, design: .default, weight: .semibold)
    static let rhythmBody = Font.system(.subheadline, design: .default, weight: .regular)
    static let rhythmCaption = Font.system(.caption, design: .default, weight: .medium)
    static let rhythmLabel = Font.system(.caption2, design: .default, weight: .semibold)
}

extension View {
    /// Section eyebrow: small, wide-tracked, quiet.
    func eyebrowStyle() -> some View {
        self.font(.rhythmLabel)
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(Palette.inkTertiary)
    }
}
