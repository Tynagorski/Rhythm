import WidgetKit
import SwiftUI

struct RhythmEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Timelines are short and anchored to the top of the hour. Rhythm's state
/// changes on user action — which reloads timelines directly — so the schedule
/// exists mainly to keep the calendar-staleness count and the "next up" copy
/// honest as the day moves.
struct RhythmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        // The gallery preview must never show a real person's tasks.
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : WidgetSnapshot.current()
        completion(RhythmEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        let snapshot = WidgetSnapshot.current()
        let now = Date()
        let calendar = Calendar.current

        // One entry now, then hourly until midnight, then a hard reload so the
        // widget flips to the new day even if the app never opens.
        var entries: [RhythmEntry] = [RhythmEntry(date: now, snapshot: snapshot)]
        for hours in 1...4 {
            guard let date = calendar.date(byAdding: .hour, value: hours, to: now),
                  calendar.isDateInToday(date) else { break }
            entries.append(RhythmEntry(date: date, snapshot: snapshot))
        }

        let midnight = calendar.startOfDay(for: now.adding(days: 1))
        completion(Timeline(entries: entries, policy: .after(min(midnight, now.addingTimeInterval(3600 * 4)))))
    }
}
