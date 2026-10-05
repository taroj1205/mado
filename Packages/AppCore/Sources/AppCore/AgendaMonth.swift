public import Foundation

public struct AgendaMonth: Sendable, Equatable {
    public struct Day: Sendable, Equatable {
        public let start: Date
        public let number: String
        public let isInMonth: Bool
        public let isToday: Bool
        public let isWeekend: Bool
        public let events: [Agenda.Event]
        public let query: String
        public let label: String
    }

    public let name: String
    public let year: String
    public let weekdays: [String]
    public let days: [Day]
    public let focused: Int
    public let heading: String
    public let detail: String
    public let badge: String
}

extension Agenda {
    static func grid(of day: Date, calendar: Calendar) -> DateInterval? {
        guard let month = calendar.dateInterval(of: .month, for: day),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end),
            let first = calendar.dateInterval(of: .weekOfYear, for: month.start),
            let last = calendar.dateInterval(of: .weekOfYear, for: lastDay)
        else { return nil }
        return DateInterval(start: first.start, end: last.end)
    }

    private static func query(for day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: day).lowercased()
    }

    private static func count(_ events: [Event]) -> String {
        switch events.count {
        case 0: "No events"
        case 1: "1 event"
        default: "\(events.count) events"
        }
    }

    private static func weekdays(in calendar: Calendar) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = (calendar.firstWeekday - 1) % symbols.count
        return Array(symbols[first...] + symbols[..<first])
    }

    public func month(showing day: Date, at now: Date, calendar: Calendar) -> AgendaMonth? {
        let focus = calendar.startOfDay(for: day)
        guard let grid = Self.grid(of: focus, calendar: calendar) else { return nil }
        let month = calendar.component(.month, from: focus)
        let full = Self.style(.dateTime.weekday(.wide).day().month(.wide), in: calendar)
        let starts = sequence(first: grid.start) { calendar.date(byAdding: .day, value: 1, to: $0) }
            .prefix { $0 < grid.end }
        let days = starts.map { start in
            let shown = events(on: start, calendar: calendar)
            return AgendaMonth.Day(
                start: start, number: start.formatted(Self.style(.dateTime.day(), in: calendar)),
                isInMonth: calendar.component(.month, from: start) == month,
                isToday: calendar.isDate(start, inSameDayAs: now),
                isWeekend: calendar.isDateInWeekend(start), events: shown,
                query: Self.query(for: start, calendar: calendar),
                label: "\(start.formatted(full)), \(Self.count(shown))")
        }
        return AgendaMonth(
            name: focus.formatted(Self.style(.dateTime.month(.wide), in: calendar)),
            year: focus.formatted(Self.style(.dateTime.year(), in: calendar)),
            weekdays: Self.weekdays(in: calendar), days: days,
            focused: days.firstIndex { $0.start == focus } ?? 0,
            heading: focus.formatted(full),
            detail: Self.count(events(on: focus, calendar: calendar)),
            badge: Self.relative(focus, at: now, calendar: calendar))
    }
}
