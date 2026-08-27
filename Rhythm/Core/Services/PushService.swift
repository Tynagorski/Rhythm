import Foundation
import UIKit

/// Client half of remote push. Rhythm's day-to-day nudges are local
/// notifications — they work offline and need no account — and APNs is reserved
/// for what only a server can do: coaching prompts derived from long-range
/// trends, and cross-device catch-ups after a silent-push sync.
///
/// `endpoint` is deliberately unset by default. Until a backend is configured
/// the token is stored locally and nothing leaves the device.
@MainActor
@Observable
final class PushService {
    static let shared = PushService()

    /// Set this to your registration endpoint to enable server-driven pushes.
    /// See Docs/PUSH_NOTIFICATIONS.md for the payload contract.
    var endpoint: URL? = nil

    private(set) var token: String?
    private(set) var lastError: String?
    private(set) var lastRegistration: Date?

    private init() {
        token = AppPreferences.shared.pushToken
    }

    var isRegistered: Bool { token != nil }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        AppPreferences.shared.pushToken = hex
        lastError = nil
        Task { await upload(token: hex) }
    }

    func didFailToRegister(error: Error) {
        lastError = error.localizedDescription
    }

    /// Handles a payload delivered while the app is running, including the
    /// silent `content-available` pushes that ask Rhythm to re-derive its state.
    @discardableResult
    func handle(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        if let raw = payload["command"] as? String {
            switch raw {
            case "refresh":
                WidgetRefresher.reloadAll()
                return .newData
            case "recompute":
                await RhythmCoordinator.shared.refreshEverything()
                return .newData
            default:
                break
            }
        }
        if let route = RhythmRoute(userInfo: payload) {
            NotificationService.shared.pendingRoute = route
        }
        return .noData
    }

    private func upload(token: String) async {
        guard let endpoint else {
            // No backend configured: the token stays on device. This is the
            // default state and is not an error.
            lastRegistration = Date()
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": "ios",
            "bundleID": Bundle.main.bundleIdentifier ?? "",
            "environment": Self.apsEnvironment,
            "timeZone": TimeZone.current.identifier,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                lastError = "Registration failed (\(http.statusCode))"
            } else {
                lastError = nil
                lastRegistration = Date()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Reads the `aps-environment` entitlement so the server knows which APNs
    /// host to send to without a separate build flag.
    static var apsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
