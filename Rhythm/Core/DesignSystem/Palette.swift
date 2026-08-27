import UIKit
import SwiftUI

/// Rhythm's colour system. Defined in code rather than an asset catalog so the
/// widget extension, the app and previews cannot drift apart, and so the dark
/// variant is always visible next to the light one.
enum Palette {

    // MARK: - Domains

    // A five-slot categorical palette. Hues and lightness were chosen by
    // optimising worst-case pairwise separation under deuteranopia, protanopia
    // and tritanopia against each mode's surface, then hand-softened. Domain
    // colour is never the only cue — every domain mark in Rhythm carries its SF
    // Symbol and its name alongside the colour.
    static let business = Color(light: 0x4257D0, dark: 0x5C77FC)
    static let body = Color(light: 0x17914A, dark: 0x0BA05D)
    static let mind = Color(light: 0xB31FA8, dark: 0xD546B8)
    static let relationships = Color(light: 0xB06A00, dark: 0xCA6E03)
    static let recovery = Color(light: 0x0E93C4, dark: 0x1187A8)

    // MARK: - Status

    // Reserved for state, never reused as a sixth domain. Always paired with a
    // glyph or a number so the state is legible without colour.
    static let positive = Color(light: 0x0E9F6E, dark: 0x0FA271)
    static let caution = Color(light: 0xB58900, dark: 0xBC8A0E)
    static let critical = Color(light: 0xDC2626, dark: 0xDE4F4F)

    // MARK: - Surfaces

    static let canvas = Color(light: 0xF6F6F4, dark: 0x0B0C0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x15171C)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1D2027)
    static let hairline = Color(light: 0xE3E3DF, dark: 0x2A2E37)

    static let ink = Color(light: 0x101114, dark: 0xF5F6F8)
    static let inkSecondary = Color(light: 0x5A5F6A, dark: 0x9AA1AE)
    static let inkTertiary = Color(light: 0x8B909B, dark: 0x6B7280)

    /// The band a balance score falls into, used for the ring and the headline.
    static func score(_ value: Int) -> Color {
        switch value {
        case ..<45: critical
        case 45..<70: caution
        default: positive
        }
    }
}

extension Color {
    /// Builds a colour that resolves differently in light and dark mode from two
    /// hex literals, keeping both variants in one line at the definition site.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
