public import Foundation

public enum DayQuery {
    private struct Shift {
        let terms: Substring
        let sign: Int
        let anchor: Date
    }

    private static let daysPerWeek = 7
    private static let leapYearCycle = 8
    private static let monthsPerYear = 12
    private static let businessDaysPerWeek = 5
    private static let saturday = 7
    private static let sunday = 1
    private static let supportedYears = 1...9_999
    private static let shortestName = 3
    private static let named = ["today": 0, "tomorrow": 1, "yesterday": -1]
    private static let weekdays = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    ]
    private static let months = [
        "january", "february", "march", "april", "may", "june", "july", "august", "september",
        "october", "november", "december",
    ]
    private static let sizes: [String: (months: Int, days: Int)] = [
        "day": (0, 1), "week": (0, daysPerWeek), "month": (1, 0), "year": (monthsPerYear, 0),
    ]

    public static func day(in query: String, now: Date, calendar: Calendar) -> Date? {
        let text = query.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let today = calendar.startOfDay(for: now)
        return keyword(text, today: today, calendar: calendar)
            ?? weekday(text, after: today, calendar: calendar)
            ?? offset(text, from: today, calendar: calendar)?.day
            ?? until(text, after: today, calendar: calendar)
            ?? date(Substring(text), after: today, calendar: calendar, past: false)
    }

    static func offset(
        _ text: String, from today: Date, calendar: Calendar
    ) -> (from: Date, day: Date)? {
        guard let shift = shift(in: text, today: today, calendar: calendar) else { return nil }
        let day =
            components(of: shift.terms, sign: shift.sign)
            .flatMap { calendar.date(byAdding: $0, to: shift.anchor) }
            ?? workdays(in: shift.terms).flatMap { count in
                businessDay(from: shift.anchor, by: shift.sign * count, calendar: calendar)
            }
        guard let day, supportedYears.contains(calendar.component(.year, from: day)) else {
            return nil
        }
        return (shift.anchor, day)
    }

    static func monthNumber(_ name: Substring) -> Int? {
        guard name.count >= shortestName else { return nil }
        return months.firstIndex { $0.hasPrefix(name) }.map { $0 + 1 }
    }

    static func weekdays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let (first, last) = start <= end ? (start, end) : (end, start)
        guard let total = calendar.dateComponents([.day], from: first, to: last).day else {
            return 0
        }
        let weeks = total / daysPerWeek
        let rest = (0..<total % daysPerWeek).filter { offset in
            calendar.date(byAdding: .day, value: weeks * daysPerWeek + offset, to: first)
                .map { day in isWeekday(day, calendar: calendar) } ?? false
        }
        return weeks * businessDaysPerWeek + rest.count
    }

    private static func isWeekday(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != saturday && weekday != sunday
    }

    private static func workdays(in text: Substring) -> Int? {
        text.wholeMatch(of: /(\d{1,4}) ?(?:(?:business|working|work) days?|weekdays?)/)
            .flatMap { Int($0.1) }
    }

    private static func businessDay(from anchor: Date, by count: Int, calendar: Calendar) -> Date? {
        let direction = count < 0 ? -1 : 1
        let move = { (date: Date?, days: Int) in
            date.flatMap { calendar.date(byAdding: .day, value: days, to: $0) }
        }
        let isOff = { (date: Date?) -> Bool in
            date.map { day in !isWeekday(day, calendar: calendar) } ?? false
        }
        var day: Date? = anchor
        while isOff(day) {
            day = move(day, -direction)
        }
        day = move(day, direction * (abs(count) / businessDaysPerWeek) * daysPerWeek)
        for _ in 0..<abs(count) % businessDaysPerWeek {
            repeat {
                day = move(day, direction)
            } while isOff(day)
        }
        return day
    }

    private static func shift(in text: String, today: Date, calendar: Calendar) -> Shift? {
        if let match = text.wholeMatch(of: /in (.+)/) {
            return Shift(terms: match.1, sign: 1, anchor: today)
        }
        if let match = text.wholeMatch(of: /(.+) (later|ago)/) {
            return Shift(terms: match.1, sign: match.2 == "ago" ? -1 : 1, anchor: today)
        }
        if let match = text.wholeMatch(of: /(.+) (from|after|before) (.+)/) {
            return anchor(match.3, today: today, calendar: calendar).map { anchor in
                Shift(terms: match.1, sign: match.2 == "before" ? -1 : 1, anchor: anchor)
            }
        }
        return text.wholeMatch(of: /(.+?) ?([+-]) ?(.+)/).flatMap { match in
            anchor(match.1, today: today, calendar: calendar).map { anchor in
                Shift(terms: match.3, sign: match.2 == "-" ? -1 : 1, anchor: anchor)
            }
        }
    }

    static func until(_ text: String, after today: Date, calendar: Calendar) -> Date? {
        text.wholeMatch(of: /(?:how many )?(?:days? )?(?:until|till|to) (.+?)\??/)
            .flatMap { target($0.1, after: today, calendar: calendar, past: false) }
            .flatMap { $0 >= today ? $0 : nil }
    }

    static func since(_ text: String, before today: Date, calendar: Calendar) -> Date? {
        text.wholeMatch(of: /(?:how many )?(?:days? )?since (.+?)\??/)
            .flatMap { target($0.1, after: today, calendar: calendar, past: true) }
            .flatMap { $0 <= today ? $0 : nil }
    }

    static func between(
        _ text: String, after today: Date, calendar: Calendar
    ) -> (start: Date, end: Date)? {
        let pattern =
            /(?:(?:how many )?days )?(?:(?:between|from) )?(.+?) (?:and|to|until|till|-) (.+?)\??/
        guard let match = text.wholeMatch(of: pattern),
            let start = target(match.1, after: today, calendar: calendar, past: false),
            let end = target(match.2, after: start, calendar: calendar, past: false)
        else { return nil }
        return (start, end)
    }

    private static func keyword(_ text: String, today: Date, calendar: Calendar) -> Date? {
        named[text].flatMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private static func anchor(_ text: Substring, today: Date, calendar: Calendar) -> Date? {
        let name = String(text)
        return name == "now"
            ? today
            : keyword(name, today: today, calendar: calendar)
                ?? weekday(name, after: today, calendar: calendar)
                ?? target(text, after: today, calendar: calendar, past: false)
    }

    private static func target(
        _ text: Substring, after today: Date, calendar: Calendar, past: Bool
    ) -> Date? {
        let holiday = text.replacing(/^(christmas|xmas)$/, with: "25 dec")
            .replacing(/^new years?( day)?$/, with: "1 jan")
        return date(holiday, after: today, calendar: calendar, past: past)
    }

    private static func components(of text: Substring, sign: Int) -> DateComponents? {
        let term = /(\d{1,6}) ?(day|week|month|year)s?(?:,? and |,? ?)/
        let terms = text.matches(of: term)
        guard !terms.isEmpty, text.replacing(term, with: "").isEmpty else { return nil }
        var monthCount = 0
        var dayCount = 0
        for match in terms {
            guard let amount = Int(match.1), let size = sizes[String(match.2)] else { return nil }
            monthCount += amount * size.months
            dayCount += amount * size.days
        }
        return DateComponents(month: sign * monthCount, day: sign * dayCount)
    }

    static func date(
        _ text: Substring, after today: Date, calendar: Calendar, past: Bool
    ) -> Date? {
        let spelled = text.replacing(/(\d)(?:st|nd|rd|th)\b/) { $0.1 }
            .replacing(/^([a-z]+) (\d+)/) { "\($0.2) \($0.1)" }
        guard let match = spelled.wholeMatch(of: /(\d{1,2}) ([a-z]+)(?: (\d{4}))?/),
            let month = monthNumber(match.2),
            let dayOfMonth = Int(match.1)
        else { return nil }
        let thisYear = calendar.component(.year, from: today)
        let given = match.3.flatMap { Int($0) }
        let candidates =
            given.map { [$0] }
            ?? (past
                ? Array((thisYear - leapYearCycle...thisYear).reversed())
                : Array(thisYear...thisYear + leapYearCycle))
        return candidates.lazy.compactMap { year in
            let components = DateComponents(year: year, month: month, day: dayOfMonth)
            guard components.isValidDate(in: calendar) else { return nil }
            return calendar.date(from: components)
        }
        .first { given != nil || (past ? $0 <= today : $0 >= today) }
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
