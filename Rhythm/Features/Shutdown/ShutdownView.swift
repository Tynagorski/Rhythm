import SwiftUI
import SwiftData

/// The end-of-day close-out. Three steps: see the day honestly, capture one
/// note, set tomorrow's keystone. It is the habit that makes every number in
/// Rhythm trustworthy.
struct ShutdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(RhythmCoordinator.self) private var coordinator
    @Environment(AppPreferences.self) private var preferences

    @State private var step = 0
    @State private var energy: Int = 3
    @State private var note: String = ""
    @State private var tomorrowKeystone: String = ""
    @State private var tomorrowDomain: Domain = .business

    private var today: [Priority] { DayQueries.priorities(on: Date(), context: context) }
    private var unfinished: [Priority] { today.filter { !$0.isDone } }
    private var result: BalanceResult { coordinator.todayResult }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 3)
                    .tint(Palette.business)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TabView(selection: $step) {
                    reviewStep.tag(0)
                    captureStep.tag(1)
                    tomorrowStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .background(Palette.canvas)
            .navigationTitle("Shutdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    // MARK: - Steps

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    HStack(spacing: 16) {
                        RingGauge(
                            progress: Double(result.score) / 100,
                            lineWidth: 10,
                            tint: Palette.score(result.score)
                        ) {
                            Text("\(result.score)")
                                .font(.rhythmMetric)
                                .foregroundStyle(Palette.ink)
                        }
                        .frame(width: 96, height: 96)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("How today actually went").eyebrowStyle()
                            Text(result.headline)
                                .font(.rhythmBody)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Still open", subtitle: unfinished.isEmpty
                                      ? "Nothing left. Close the laptop."
                                      : "Move it or drop it — do not carry it silently.")
                        if unfinished.isEmpty {
                            Label("Everything you committed to is done.", systemImage: "checkmark.seal.fill")
                                .font(.rhythmBody)
                                .foregroundStyle(Palette.positive)
                        } else {
                            ForEach(unfinished) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.tier.symbol)
                                        .foregroundStyle(item.domain.tint)
                                        .frame(width: 20)
                                    Text(item.title)
                                        .font(.rhythmBody)
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(2)
                                    Spacer(minLength: 8)
                                    Button("Tomorrow") { push(item) }
                                        .font(.rhythmLabel)
                                        .buttonStyle(.bordered)
                                    Button {
                                        withAnimation { context.delete(item) }
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .font(.rhythmLabel)
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Drop \(item.title)")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var captureStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Energy", subtitle: "Not mood. What you had left to give.")
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    withAnimation(.snappy) { energy = value }
                                } label: {
                                    Text("\(value)")
                                        .font(.rhythmMetricSmall)
                                        .frame(maxWidth: .infinity, minHeight: 46)
                                        .foregroundStyle(energy == value ? .white : Palette.ink)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(energy == value ? Palette.business : Palette.canvas)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Energy \(value) of 5")
                                .accessibilityAddTraits(energy == value ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                        Text(Self.energyCopy(energy))
                            .font(.rhythmCaption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("One line", subtitle: "What actually decided today?")
                        TextField("A sentence is enough", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.rhythmBody)
                    }
                }
            }
            .padding(16)
        }
    }

    private var tomorrowStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Tomorrow's keystone",
                                      subtitle: "Decide it now, while you still have today's context.")
                        TextField("The one thing", text: $tomorrowKeystone, axis: .vertical)
                            .font(.rhythmHeadline)
                            .lineLimit(1...3)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Domain.allCases) { domain in
                                    Button { tomorrowDomain = domain } label: {
                                        DomainChip(domain: domain, isSelected: tomorrowDomain == domain)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollClipDisabled()
                    }
                }

                if let worst = coordinator.drift.worst {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader("A nudge")
                            Text("\(worst.title) has gone \(coordinator.drift.staleness(worst)) days without anything. Tomorrow is a cheap place to fix that.")
                                .font(.rhythmBody)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Make tomorrow's keystone \(worst.title.lowercased())") {
                                tomorrowDomain = worst
                            }
                            .font(.rhythmCaption)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button(step == 2 ? "Close the day" : "Next") {
                if step < 2 {
                    withAnimation { step += 1 }
                } else {
                    complete()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    // MARK: - Actions

    private func push(_ priority: Priority) {
        withAnimation { priority.day = priority.day.adding(days: 1) }
        try? context.save()
    }

    private func complete() {
        let log = DayQueries.dayLog(forOrCreating: Date(), context: context)
        log.shutdownCompletedAt = Date()
        log.energy = energy
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let keystoneTitle = tomorrowKeystone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keystoneTitle.isEmpty {
            let tomorrow = Date().adding(days: 1).startOfDay
            for existing in DayQueries.priorities(on: tomorrow, context: context)
            where existing.tier == .keystone {
                existing.tier = .momentum
            }
            context.insert(Priority(
                title: keystoneTitle,
                tier: .keystone,
                domain: tomorrowDomain,
                day: tomorrow
            ))
        }

        try? context.save()
        Task {
            await coordinator.refreshEverything(preferences: preferences)
            dismiss()
        }
    }

    static func energyCopy(_ value: Int) -> String {
        switch value {
        case 1: "Empty. Tomorrow starts with recovery, not ambition."
        case 2: "Running low. Cut tomorrow's list before it cuts you."
        case 3: "Even. The sustainable number, not the impressive one."
        case 4: "Good reserves. A day worth understanding and repeating."
        default: "Full. Note what produced this — it is rarer than it feels."
        }
    }
}
