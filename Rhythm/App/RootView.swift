import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(NotificationService.self) private var notifications
    @Environment(RhythmCoordinator.self) private var coordinator

    @State private var selection: RhythmRoute = .today
    @State private var showingCalendarReview = false
    @State private var showingShutdown = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView(onOpenShutdown: { showingShutdown = true },
                      onOpenCalendarReview: { showingCalendarReview = true })
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                .tag(RhythmRoute.today)

            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar.day.timeline.left") }
                .tag(RhythmRoute.plan)

            RitualsView()
                .tabItem { Label("Rituals", systemImage: "repeat.circle.fill") }
                .tag(RhythmRoute.rituals)

            BalanceView()
                .tabItem { Label("Balance", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(RhythmRoute.balance)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(RhythmRoute.settings)
        }
        .background(Palette.canvas)
        .sheet(isPresented: $showingCalendarReview) {
            CalendarReviewView()
        }
        .sheet(isPresented: $showingShutdown) {
            ShutdownView()
        }
        .fullScreenCover(isPresented: .init(
            get: { !preferences.hasCompletedOnboarding },
            set: { if !$0 { preferences.hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
        .onChange(of: notifications.pendingRoute) { _, route in
            guard let route else { return }
            handle(route)
            notifications.pendingRoute = nil
        }
    }

    /// Sheets are routes too — a calendar nudge should open the review, not just
    /// the tab it lives behind.
    private func handle(_ route: RhythmRoute) {
        switch route {
        case .calendarReview:
            selection = .today
            showingCalendarReview = true
        case .shutdown:
            selection = .today
            showingShutdown = true
        default:
            selection = route
        }
    }
}

#Preview {
    RootView()
        .environment(AppPreferences.shared)
        .environment(RhythmCoordinator.shared)
        .environment(CalendarService.shared)
        .environment(NotificationService.shared)
        .modelContainer(try! RhythmStore.inMemoryContainer())
}
