public import Foundation

public struct CalendarMonth: Sendable, Equatable {
    public struct Day: Sendable, Equatable {
        public let number: String
        public let isInMonth: Bool
        public let isToday: Bool
    }

    public let title: String
    public let weekdays: [String]
    public let days: [Day]

    public init?(around now: Date, calendar: Calendar) {
        guard let month = calendar.dateInterval(of: .month, for: now),
            let first = calendar.dateInterval(of: .weekOfMonth, for: month.start),
            let last = calendar.dateInterval(of: .weekOfMonth, for: month.end - 1)
        else { return nil }
        var heading = Date.FormatStyle.dateTime.month(.wide).year()
        var number = Date.FormatStyle.dateTime.day()
        heading.calendar = calendar
        heading.timeZone = calendar.timeZone
        number.calendar = calendar
        number.timeZone = calendar.timeZone
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        var grid: [Day] = []
        var day = first.start
        while day < last.end {
            grid.append(
                Day(
                    number: day.formatted(number),
                    isInMonth: calendar.isDate(day, equalTo: now, toGranularity: .month),
                    isToday: calendar.isDate(day, inSameDayAs: now)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        title = now.formatted(heading)
        weekdays = Array(symbols[shift...] + symbols[..<shift])
        days = grid
    }
}
