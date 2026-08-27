import Foundation

/// Identifiers shared by the app, the widget extension and the App Intents that
/// run inside it. Changing `identifier` requires updating both entitlements
/// files or the widgets will silently fall back to an empty store.
enum AppGroup {
    static let identifier = "group.com.rhythm.app"
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

enum WidgetKinds {
    static let today = "RhythmTodayWidget"
    static let balance = "RhythmBalanceWidget"
    static let rituals = "RhythmRitualsWidget"
    static let calendarIntegrity = "RhythmCalendarIntegrityWidget"
    static let lockScreen = "RhythmLockScreenWidget"
}
