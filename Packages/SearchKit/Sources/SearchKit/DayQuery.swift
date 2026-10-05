public import Foundation

public enum DayQuery {
    private static let daysPerWeek = 7
    private static let leapYearCycle = 8
    private static let shortestName = 3
    private static let named = ["today": 0, "tomorrow": 1, "yesterday": -1]
    private static let weekdays = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    ]
    private static let months = [
        "january", "february", "march", "april", "may", "june", "july", "august", "september",
        "october", "november", "december",
    ]
    private static let steps: [String: Calendar.Component] = [
        "day": .day, "week": .weekOfYear, "month": .month, "year": .year,
    ]

    public static func day(in query: String, now: Date, calendar: Calendar) -> Date? {
        let text = query.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let today = calendar.startOfDay(for: now)
        return named[text].flatMap { calendar.date(byAdding: .day, value: $0, to: today) }
            ?? weekday(text, after: today, calendar: calendar)
            ?? offset(text, from: today, calendar: calendar)
            ?? until(text, after: today, calendar: calendar)
            ?? date(Substring(text), after: today, calendar: calendar)
    }

    static func offset(_ text: String, from today: Date, calendar: Calendar) -> Date? {
        let pattern = /(in )?(\d+) ?(day|week|month|year)s?(?: (from today|from now|later|ago))?/
        guard let match = text.wholeMatch(of: pattern), match.1 != nil || match.4 != nil,
            let amount = Int(match.2), let step = steps[String(match.3)]
        else { return nil }
        return calendar.date(byAdding: step, value: match.4 == "ago" ? -amount : amount, to: today)
    }

    static func until(_ text: String, after today: Date, calendar: Calendar) -> Date? {
        text.wholeMatch(of: /(?:how many )?(?:days? )?(?:until|till|to) (.+?)\??/)
            .flatMap { match in
                let holiday = match.1.replacing(/^(christmas|xmas)$/, with: "25 dec")
                    .replacing(/^new years?( day)?$/, with: "1 jan")
                return date(holiday, after: today, calendar: calendar)
            }
            .flatMap { $0 >= today ? $0 : nil }
    }

    static func date(_ text: Substring, after today: Date, calendar: Calendar) -> Date? {
        let spelled = text.replacing(/(\d)(?:st|nd|rd|th)\b/) { $0.1 }
            .replacing(/^([a-z]+) (\d+)/) { "\($0.2) \($0.1)" }
        guard let match = spelled.wholeMatch(of: /(\d{1,2}) ([a-z]+)(?: (\d{4}))?/),
            match.2.count >= shortestName,
            let month = months.firstIndex(where: { $0.hasPrefix(match.2) }),
            let dayOfMonth = Int(match.1)
        else { return nil }
        let thisYear = calendar.component(.year, from: today)
        let given = match.3.flatMap { Int($0) }.map { $0...$0 }
        let years = given ?? thisYear...thisYear + leapYearCycle
        return years.lazy.compactMap { year in
            let components = DateComponents(year: year, month: month + 1, day: dayOfMonth)
            guard components.isValidDate(in: calendar) else { return nil }
            return calendar.date(from: components)
        }
        .first { given != nil || $0 >= today }
    }

    private static func weekday(_ text: String, after today: Date, calendar: Calendar) -> Date? {
        guard let match = text.wholeMatch(of: /(?:(next|this) )?([a-z]+)/) else { return nil }
        let name = match.2
        let index = weekdays.firstIndex { weekday in
            match.1 == nil ? weekday == name : name.count >= shortestName && weekday.hasPrefix(name)
        }
        guard let index else { return nil }
        let ahead =
            (index + 1 - calendar.component(.weekday, from: today) + daysPerWeek)
            % daysPerWeek
        let days = match.1 == "next" && ahead == 0 ? daysPerWeek : ahead
        return calendar.date(byAdding: .day, value: days, to: today)
    }
}
