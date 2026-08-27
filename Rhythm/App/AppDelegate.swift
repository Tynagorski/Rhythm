import UIKit

/// SwiftUI has no hook for the APNs registration callbacks, so Rhythm keeps a
/// minimal delegate purely to forward them to `PushService`.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Registering here (rather than only after the permission prompt) lets a
        // user who has already granted permission receive silent pushes on every
        // subsequent launch without being asked again.
        Task { @MainActor in
            if NotificationService.shared.isAuthorized {
                NotificationService.shared.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushService.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in PushService.shared.didFailToRegister(error: error) }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await PushService.shared.handle(payload: userInfo)
    }
}
