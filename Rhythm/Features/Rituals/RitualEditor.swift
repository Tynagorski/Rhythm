import SwiftUI
import SwiftData

struct RitualEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    var existing: Ritual?

    @State private var name: String
    @State private var detail: String
    @State private var domain: Domain
    @State private var cadence: Cadence
    @State private var targetPerWeek: Int
    @State private var anchor: Date
    @State private var remindersEnabled: Bool

    init(existing: Ritual? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _detail = State(initialValue: existing?.detail ?? "")
        _domain = State(initialValue: existing?.domain ?? .body)
        _cadence = State(initialValue: existing?.cadence ?? .daily)
        _targetPerWeek = State(initialValue: existing?.targetPerWeek ?? 3)
        _anchor = State(initialValue: existing?.anchor ?? Date().startOfDay.settingTime(minutesFromMidnight: 7 * 60))
        _remindersEnabled = State(initialValue: existing?.remindersEnabled ?? true)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ritual", text: $name)
                        .font(.rhythmHeadline)
                    TextField("What it looks like when kept", text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Domain") {
                    Picker("Domain", selection: $domain) {
                        ForEach(Domain.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                }

                Section("Cadence") {
                    Picker("Cadence", selection: $cadence) {
                        ForEach(Cadence.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if cadence == .timesPerWeek {
                        Stepper("\(targetPerWeek) times a week", value: $targetPerWeek, in: 1...7)
                    }
                    DatePicker("Anchor time", selection: $anchor, displayedComponents: .hourAndMinute)
                    Text("Anchoring a ritual to a time makes it a decision you already made, not one you make again every day.")
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.inkTertiary)
                }

                Section("Reminder") {
                    Toggle("Remind me at the anchor", isOn: $remindersEnabled)
                    if !preferences.ritualRemindersEnabled && remindersEnabled {
                        Label("Ritual reminders are off globally in Settings.", systemImage: "bell.slash")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.caution)
                    }
                }

                if let existing {
                    Section {
                        Button("Archive ritual", role: .destructive) {
                            existing.isArchived = true
                            save(skipUpsert: true)
                        }
                    } footer: {
                        Text("Archiving keeps the history but stops the reminders and removes it from today.")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New ritual" : "Edit ritual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save(skipUpsert: Bool = false) {
        if !skipUpsert {
            if let existing {
                existing.name = trimmedName
                existing.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.domain = domain
                existing.cadence = cadence
                existing.targetPerWeek = targetPerWeek
                existing.anchor = anchor
                existing.remindersEnabled = remindersEnabled
            } else {
                let count = DayQueries.activeRituals(context: context).count
                let ritual = Ritual(
                    name: trimmedName,
                    detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                    domain: domain,
                    cadence: cadence,
                    targetPerWeek: targetPerWeek,
                    anchor: anchor,
                    remindersEnabled: remindersEnabled,
                    sortIndex: count
                )
                context.insert(ritual)
            }
        }

        try? context.save()
        Task {
            await coordinator.rescheduleNotifications(preferences: preferences)
            coordinator.refreshScoreOnly(preferences: preferences)
        }
        dismiss()
    }
}
