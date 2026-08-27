import SwiftUI
import SwiftData

@main
struct RhythmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container = RhythmStore.shared
    @State private var preferences = AppPreferences.shared
    @State private var coordinator = RhythmCoordinator.shared
    @State private var calendar = CalendarService.shared
    @State private var notifications = NotificationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .environment(coordinator)
                .environment(calendar)
                .environment(notifications)
                .tint(Palette.business)
                .task {
                    // Deliberately here rather than in `init()`: this is
                    // main-actor work, and `App.init` is not isolated.
                    coordinator.configure(container: container)
                    notifications.bootstrap()
                    coordinator.seedRitualsIfNeeded(preferences: preferences)
                    await notifications.refreshAuthorization()
                    await coordinator.refreshEverything(preferences: preferences)
                }
                .onOpenURL { url in
                    if let route = DeepLink.route(from: url) {
                        notifications.pendingRoute = route
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await coordinator.refreshEverything(preferences: preferences) }
        }
    }
}
