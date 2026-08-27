import SwiftUI
import SwiftData

/// Creates or edits a single priority. Tier limits are enforced here rather than
/// in the model so the user gets an explanation instead of a silent failure.
struct PriorityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    var day: Date
    var existing: Priority?

    @State private var title: String
    @State private var details: String
    @State private var tier: PriorityTier
    @State private var domain: Domain
    @State private var estimate: Int
    @State private var targetDay: Date

    @FocusState private var titleFocused: Bool

    init(day: Date, tier: PriorityTier = .momentum, existing: Priority? = nil) {
        self.day = day
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _details = State(initialValue: existing?.details ?? "")
        _tier = State(initialValue: existing?.tier ?? tier)
        _domain = State(initialValue: existing?.domain ?? .business)
        _estimate = State(initialValue: existing?.estimateMinutes ?? 30)
        _targetDay = State(initialValue: existing?.day ?? day.startOfDay)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Existing items of the chosen tier on the chosen day, excluding this one.
    private var siblingCount: Int {
        DayQueries.priorities(on: targetDay, context: context)
            .filter { $0.tier == tier && $0.id != existing?.id }
            .count
    }

    private var limitWarning: String? {
        guard let limit = tier.dailyLimit, siblingCount >= limit else { return nil }
        return tier == .keystone
            ? "There is already a keystone for this day. Saving replaces which one leads — you can only have one."
            : "That is \(siblingCount) of \(limit) already. Momentum is capped on purpose."
    }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        guard let limit = tier.dailyLimit else { return true }
        // A keystone swap is allowed; exceeding the momentum cap is not.
        return tier == .keystone || siblingCount < limit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $title, axis: .vertical)
                        .font(.rhythmHeadline)
                        .focused($titleFocused)
                    TextField("Why it matters (optional)", text: $details, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Weight") {
                    Picker("Tier", selection: $tier) {
                        ForEach(PriorityTier.allCases, id: \.self) { tier in
                            Text(tier.title).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(tier.subtitle)
                        .font(.rhythmCaption)
                        .foregroundStyle(Palette.inkSecondary)

                    if let limitWarning {
                        Label(limitWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.caution)
                    }
                }

                Section("Domain") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Domain.allCases) { option in
                                Button {
                                    domain = option
                                } label: {
                                    DomainChip(domain: option, isSelected: domain == option)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()

                    if domain.isWork {
                        Text("Every task cannot be business. Rhythm scores coverage, not volume.")
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                Section("Shape") {
                    DatePicker("Day", selection: $targetDay, displayedComponents: .date)
                    Stepper(
                        "Estimate: \(estimate.durationLabel)",
                        value: $estimate,
                        in: 0...480,
                        step: 15
                    )
                }
            }
            .navigationTitle(existing == nil ? "New priority" : "Edit priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear { titleFocused = existing == nil }
        }
    }

    private func save() {
        let start = targetDay.startOfDay

        // Only one keystone per day: demote whatever held the slot.
        if tier == .keystone {
            for other in DayQueries.priorities(on: start, context: context)
            where other.tier == .keystone && other.id != existing?.id {
                other.tier = .momentum
            }
        }

        if let existing {
            existing.title = trimmedTitle
            existing.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.tier = tier
            existing.domain = domain
            existing.day = start
            existing.estimateMinutes = estimate
        } else {
            let priority = Priority(
                title: trimmedTitle,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                tier: tier,
                domain: domain,
                day: start,
                estimateMinutes: estimate,
                sortIndex: siblingCount
            )
            context.insert(priority)
        }

        try? context.save()
        coordinator.refreshScoreOnly(preferences: preferences)
        dismiss()
    }
}
