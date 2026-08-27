import SwiftUI

/// Four screens, each of which asks for exactly one thing. Permissions are
/// requested in context — after explaining what they buy — rather than in a
/// burst on launch.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var preferences
    @Environment(NotificationService.self) private var notifications
    @Environment(CalendarService.self) private var calendarService
    @Environment(RhythmCoordinator.self) private var coordinator

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                intro.tag(0)
                boundaries.tag(1)
                calendarStep.tag(2)
                notificationStep.tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == 3 ? "Start" : "Continue") {
                if page < 3 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas)
    }

    // MARK: - Pages

    private var intro: some View {
        OnboardingPage(
            symbol: "metronome.fill",
            title: "Rhythm",
            message: "You are not short on effort. You are short on a system that holds the parts of your life your calendar does not.\n\nRhythm scores four things every day: what you executed, what rituals you kept, how many parts of your life the day touched, and whether your boundaries held."
        )
    }

    private var boundaries: some View {
        @Bindable var preferences = preferences
        return OnboardingPage(
            symbol: "clock.badge.checkmark.fill",
            title: "Set the edges",
            message: "Everything after your hard stop counts against you. That is deliberate — a boundary you never enforce is not a boundary."
        ) {
            VStack(spacing: 8) {
                LabeledTime(title: "Workday starts", minutes: $preferences.workdayStartMinutes)
                LabeledTime(title: "Hard stop", minutes: $preferences.workdayEndMinutes)
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var calendarStep: some View {
        OnboardingPage(
            symbol: "calendar.badge.exclamationmark",
            title: "Keep the calendar honest",
            message: "Rhythm reads your calendar — never writes to it — to find conflicts, unanswered invites, and days with no room left to think.\n\nEvery few days it will make you look at the week ahead. That nag is the feature."
        ) {
            Button(calendarService.hasAccess ? "Calendar connected" : "Connect calendar") {
                Task { await calendarService.requestAccess() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(calendarService.hasAccess)
        }
    }

    private var notificationStep: some View {
        OnboardingPage(
            symbol: "bell.badge.fill",
            title: "A few, at the right moments",
            message: "A morning brief, a midday checkpoint, your rituals at their anchor times, and a shutdown at your hard stop. Plus the calendar nudge, which escalates until you deal with it.\n\nEvery one of them can be turned off individually."
        ) {
            Button(notifications.isAuthorized ? "Notifications on" : "Enable notifications") {
                Task { await notifications.requestAuthorization() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(notifications.isAuthorized)
        }
    }

    private func finish() {
        preferences.hasCompletedOnboarding = true
        preferences.lastCalendarReview = Date()
        coordinator.seedRitualsIfNeeded(preferences: preferences)
        Task { await coordinator.refreshEverything(preferences: preferences) }
        dismiss()
    }
}

struct OnboardingPage<Accessory: View>: View {
    var symbol: String
    var title: String
    /// Named `message` rather than `body`, which belongs to `View`.
    var message: String
    @ViewBuilder var accessory: Accessory

    init(
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.accessory = accessory()
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Palette.business)
            Text(title)
                .font(.rhythmDisplay)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.rhythmBody)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            accessory
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 48)
    }
}
