import Foundation

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func settingTime(minutesFromMidnight: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutesFromMidnight, to: startOfDay) ?? self
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    /// "Today", "Tomorrow", otherwise "Thu 14".
    var relativeDayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return formatted(.dateTime.weekday(.abbreviated).day())
    }

    var timeLabel: String { formatted(date: .omitted, time: .shortened) }

    var weekdayInitial: String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let index = Calendar.current.component(.weekday, from: self) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}

extension Calendar {
    /// Every day in the week containing `date`, starting on the locale's first
    /// weekday.
    func daysOfWeek(containing date: Date) -> [Date] {
        guard let interval = dateInterval(of: .weekOfYear, for: date) else { return [date.startOfDay] }
        return (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: interval.start) }
    }
}

extension Int {
    /// 95 -> "1h 35m", 60 -> "1h", 45 -> "45m".
    var durationLabel: String {
        guard self > 0 else { return "0m" }
        let hours = self / 60
        let minutes = self % 60
        switch (hours, minutes) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }
}
