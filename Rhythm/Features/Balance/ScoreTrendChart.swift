import Charts
import SwiftUI

/// Daily balance score over the selected window.
///
/// One series, so no legend: the section title names it. Height carries the
/// value on its own — the band colour is redundant reinforcement, never the only
/// cue — and the 70 target line gives the eye a fixed reference instead of
/// asking it to decode a hue.
struct ScoreTrendChart: View {
    var logs: [DayLog]
    /// The score Rhythm treats as "a good day".
    var target: Int = 70

    @State private var selectedDay: Date?

    private var selected: DayLog? {
        guard let selectedDay else { return nil }
        return logs.min {
            abs($0.day.timeIntervalSince(selectedDay)) < abs($1.day.timeIntervalSince(selectedDay))
        }
    }

    private var average: Int {
        guard !logs.isEmpty else { return 0 }
        return Int((Double(logs.reduce(0) { $0 + $1.balanceScore }) / Double(logs.count)).rounded())
    }

    private var latest: DayLog? { logs.last }

    var body: some View {
        Chart {
            ForEach(logs) { log in
                BarMark(
                    x: .value("Day", log.day, unit: .day),
                    y: .value("Balance", log.balanceScore),
                    width: .ratio(0.62)
                )
                .foregroundStyle(Palette.score(log.balanceScore))
                .cornerRadius(4)
                .opacity(selected == nil || selected?.day == log.day ? 1 : 0.35)
                .accessibilityLabel(log.day.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityValue("Balance \(log.balanceScore) out of 100")
            }

            RuleMark(y: .value("Target", target))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Palette.inkTertiary.opacity(0.6))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("target \(target)")
                        .font(.rhythmLabel)
                        .foregroundStyle(Palette.inkTertiary)
                }

            if let selected {
                RuleMark(x: .value("Day", selected.day, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Palette.hairline)
                    .zIndex(-1)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel {
                    if let score = value.as(Int.self) {
                        Text("\(score)")
                            .font(.rhythmLabel)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, logs.count / 6))) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(logs.count > 10
                             ? date.formatted(.dateTime.day())
                             : date.weekdayInitial)
                            .font(.rhythmLabel)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDay)
        .overlay(alignment: .topTrailing) { readout }
        .accessibilityChartDescriptor(self)
    }

    /// Doubles as the tooltip and as the resting direct label, so there is
    /// always exactly one number on the chart rather than one per bar.
    private var readout: some View {
        let log = selected ?? latest
        return Group {
            if let log {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(log.balanceScore)")
                        .font(.rhythmMetricSmall)
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text(selected == nil ? "latest · avg \(average)" : log.day.relativeDayLabel)
                        .font(.rhythmLabel)
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Palette.surfaceRaised.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
                .allowsHitTesting(false)
            }
        }
    }
}

/// VoiceOver users get the same series as an audio graph and a spoken summary.
extension ScoreTrendChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let scores = logs.map { Double($0.balanceScore) }
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Day",
            range: 0...Double(max(1, logs.count - 1)),
            gridlinePositions: []
        ) { index in
            let position = Int(index.rounded())
            guard logs.indices.contains(position) else { return "" }
            return logs[position].day.formatted(.dateTime.month().day())
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Balance score",
            range: 0...100,
            gridlinePositions: [0, 50, 100]
        ) { "\(Int($0.rounded())) out of 100" }

        let series = AXDataSeriesDescriptor(
            name: "Daily balance",
            isContinuous: false,
            dataPoints: scores.enumerated().map { index, score in
                AXDataPoint(x: Double(index), y: score)
            }
        )

        return AXChartDescriptor(
            title: "Balance score trend",
            summary: "Average \(average) out of 100 across \(logs.count) days. Target is \(target).",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
