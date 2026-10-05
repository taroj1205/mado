import Foundation

enum DateFacts {
    private static let leapYearDays = 366
    private static let relative = ["this": 0, "next": 1, "last": -1]

    static func answer(for text: String, now: Date, calendar: Calendar) -> Calculator.Answer? {
        leapYear(text, calendar: calendar) ?? length(text, now: now, calendar: calendar)
    }

    private static func leapYear(_ text: String, calendar: Calendar) -> Calculator.Answer? {
        let pattern = /(?:is )?(?:(\d{4}) (?:a )?leap year|leap year (\d{4}))\??/
        guard let match = text.wholeMatch(of: pattern),
            let year = (match.1 ?? match.2).flatMap({ Int($0) }),
            let days = days(of: .year, startingAt: first(year: year, month: 1, calendar), calendar)
        else { return nil }
        return Calculator.Answer(
            kind: "Dates", expression: "Is \(year) a leap year?",
            expressionDetail: "Gregorian calendar", result: days == leapYearDays ? "Yes" : "No",
            resultDetail: TimeMath.count(days, "day"))
    }

    private static func length(
        _ text: String, now: Date, calendar: Calendar
    ) -> Calculator.Answer? {
        guard let rest = text.wholeMatch(of: /(?:how many )?days (?:are )?in (.+?)\??/)?.1,
            let (unit, start) = period(String(rest), now: now, calendar: calendar),
            let days = days(of: unit, startingAt: start, calendar)
        else { return nil }
        let isYear = unit == .year
        return Calculator.Answer(
            kind: "Dates",
            expression: "Days in \(TimeMath.label(start, isYear ? "yyyy" : "MMMM yyyy", calendar))",
            expressionDetail: isYear
                ? (days == leapYearDays ? "Leap year" : "Common year") : "Month length",
            result: TimeMath.count(days, "day"), resultDetail: TimeMath.weeksAndDays(days))
    }

    private static func period(
        _ text: String, now: Date, calendar: Calendar
    ) -> (Calendar.Component, Date)? {
        let thisYear = calendar.component(.year, from: now)
        if let match = text.wholeMatch(of: /(this|next|last) (month|year)/) {
            return shifted(match.1, match.2, now: now, calendar: calendar)
        }
        if let match = text.wholeMatch(of: /(\d{4})/) {
            return first(year: Int(match.1), month: 1, calendar).map { (.year, $0) }
        }
        guard let match = text.wholeMatch(of: /([a-z]{3,9})(?: (\d{4}))?/),
            let month = DayQuery.monthNumber(match.1)
        else { return nil }
        return first(year: match.2.flatMap { Int($0) } ?? thisYear, month: month, calendar)
            .map { (.month, $0) }
    }

    private static func shifted(
        _ when: Substring, _ unit: Substring, now: Date, calendar: Calendar
    ) -> (Calendar.Component, Date)? {
        guard let offset = relative[String(when)] else { return nil }
        let component: Calendar.Component = unit == "year" ? .year : .month
        let base = calendar.date(byAdding: component, value: offset, to: now) ?? now
        let parts = calendar.dateComponents([.year, .month], from: base)
        return first(year: parts.year, month: component == .year ? 1 : parts.month, calendar)
            .map { start in (component, start) }
    }

    private static func first(year: Int?, month: Int?, _ calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private static func days(
        of unit: Calendar.Component, startingAt start: Date?, _ calendar: Calendar
    ) -> Int? {
        start.flatMap { calendar.range(of: .day, in: unit, for: $0)?.count }
    }
}
