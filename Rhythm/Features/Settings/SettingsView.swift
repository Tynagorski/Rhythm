import SwiftUI
import EventKit
import UIKit

struct SettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(NotificationService.self) private var notifications
    @Environment(CalendarService.self) private var calendarService
    @Environment(RhythmCoordinator.self) private var coordinator

    @State private var push = PushService.shared
    @State private var showingCalendarPicker = false

    var body: some View {
        @Bindable var preferences = preferences

        NavigationStack {
            Form {
                Section {
                    LabeledTime(title: "Workday starts", minutes: $preferences.workdayStartMinutes)
                    LabeledTime(title: "Hard stop", minutes: $preferences.workdayEndMinutes)
                } header: {
                    Text("Boundaries")
                } footer: {
                    Text("Everything after your hard stop counts against protection. That is the point — the number only means something if the boundary is real.")
                }

                Section {
                    Stepper(
                        "Every \(preferences.calendarReviewIntervalDays) days",
                        value: $preferences.calendarReviewIntervalDays,
                        in: 1...14
                    )
                    Toggle("Calendar nudges", isOn: $preferences.calendarNudgeEnabled)
                    if let days = preferences.daysSinceCalendarReview {
                        LabeledContent("Last reviewed", value: days == 0 ? "Today" : "\(days) days ago")
                    } else {
                        LabeledContent("Last reviewed", value: "Never")
                    }
                    Button("Choose calendars") { showingCalendarPicker = true }
                        .disabled(!calendarService.hasAccess)
                } header: {
                    Text("Calendar review")
                } footer: {
                    Text("Rhythm reads your calendar to spot conflicts, unanswered invites and days with no room to think. It never writes to it.")
                }

                Section {
                    if notifications.isAuthorized {
                        Toggle("Morning brief", isOn: $preferences.morningBriefEnabled)
                        if preferences.morningBriefEnabled {
                            LabeledTime(title: "Brief at", minutes: $preferences.morningBriefMinutes)
                        }
                        Toggle("Midday checkpoint", isOn: $preferences.middayCheckEnabled)
                        if preferences.middayCheckEnabled {
                            LabeledTime(title: "Checkpoint at", minutes: $preferences.middayCheckMinutes)
                        }
                        Toggle("Shutdown reminder", isOn: $preferences.shutdownEnabled)
                        Toggle("Ritual reminders", isOn: $preferences.ritualRemindersEnabled)
                        Toggle("Drift alerts", isOn: $preferences.driftAlertsEnabled)
                        Toggle("Quiet weekends", isOn: $preferences.quietWeekends)
                    } else {
                        Button("Turn on notifications") {
                            Task {
                                await notifications.requestAuthorization()
                                await coordinator.rescheduleNotifications(preferences: preferences)
                            }
                        }
                        Text("Without notifications Rhythm cannot nudge you to update your calendar — which is most of what it is for.")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                } header: {
                    Text("Notifications")
                }

                Section {
                    LabeledContent("Remote notifications",
                                   value: push.isRegistered ? "Registered" : "Not registered")
                    if let registered = push.lastRegistration {
                        LabeledContent("Token refreshed",
                                       value: registered.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let error = push.lastError {
                        Text(error)
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.critical)
                    }
                    if push.endpoint == nil {
                        Text("No push server is configured, so the device token stays on this device. Day-to-day nudges are scheduled locally and work offline.")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                } header: {
                    Text("Push")
                }

                Section("Widgets") {
                    Text("Add Rhythm widgets from the home screen: touch and hold the background, tap Edit, then Add Widget. The lock screen widgets live in the clock's customise screen.")
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Section {
                    Link("Privacy policy", destination: URL(string: "https://rhythm.app/privacy")!)
                    Link("Support", destination: URL(string: "https://rhythm.app/support")!)
                    LabeledContent("Version", value: Self.versionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("Your plans, rituals and calendar analysis stay on your device. Rhythm has no account and no analytics.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCalendarPicker) { CalendarPickerView() }
            .onChange(of: preferences.workdayStartMinutes) { _, _ in resync() }
            .onChange(of: preferences.workdayEndMinutes) { _, _ in resync() }
            .onChange(of: preferences.morningBriefMinutes) { _, _ in resync() }
            .onChange(of: preferences.middayCheckMinutes) { _, _ in resync() }
            .onChange(of: preferences.calendarReviewIntervalDays) { _, _ in resync() }
            .onChange(of: preferences.morningBriefEnabled) { _, _ in resync() }
            .onChange(of: preferences.middayCheckEnabled) { _, _ in resync() }
            .onChange(of: preferences.shutdownEnabled) { _, _ in resync() }
            .onChange(of: preferences.calendarNudgeEnabled) { _, _ in resync() }
            .onChange(of: preferences.ritualRemindersEnabled) { _, _ in resync() }
            .onChange(of: preferences.driftAlertsEnabled) { _, _ in resync() }
            .onChange(of: preferences.quietWeekends) { _, _ in resync() }
        }
    }

    private func resync() {
        Task { await coordinator.rescheduleNotifications(preferences: preferences) }
        WidgetRefresher.reloadAll()
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// A time row backed by minutes-from-midnight rather than a `Date`, so the
/// stored boundary means the same thing in every time zone.
struct LabeledTime: View {
    var title: String
    @Binding var minutes: Int

    private var date: Binding<Date> {
        Binding(
            get: { Date().startOfDay.settingTime(minutesFromMidnight: minutes) },
            set: { minutes = AppPreferences.minutes(from: $0) }
        )
    }

    var body: some View {
        DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
    }
}

/// Lets the user narrow which calendars Rhythm analyses — most professionals
/// have a shared team calendar they do not want counted as personal load.
struct CalendarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarService.self) private var calendarService
    @Environment(AppPreferences.self) private var preferences
    @Environment(RhythmCoordinator.self) private var coordinator

    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(calendarService.availableCalendars(), id: \.calendarIdentifier) { calendar in
                        Button {
                            toggle(calendar.calendarIdentifier)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                if selected.isEmpty || selected.contains(calendar.calendarIdentifier) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Palette.business)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("With nothing selected, Rhythm reads every calendar.")
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        preferences.enabledCalendarIDs = Array(selected)
                        Task { await coordinator.refreshEverything(preferences: preferences) }
                        dismiss()
                    }
                }
            }
            .onAppear { selected = Set(preferences.enabledCalendarIDs) }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}
