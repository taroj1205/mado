import Foundation
import Testing

@testable import SearchKit

@Suite struct DateMathTests {
    private static let today = "2026-10-02"

    private static func date(_ text: String) throws -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 14)
        return try #require(calendar.date(from: components))
    }

    @Test(arguments: [
        ("today + 90 days", "2026-10-02", "From Fri, 2 Oct 2026", "31 Dec 2026"),
        ("1 jan 2027 + 30 days", "2026-10-02", "From Fri, 1 Jan 2027", "31 Jan 2027"),
        ("25 dec - 2 weeks", "2026-10-02", "From Fri, 25 Dec 2026", "11 Dec 2026"),
        ("90 days from 1 jan 2027", "2026-10-02", "From Fri, 1 Jan 2027", "1 Apr 2027"),
        ("3 days before christmas", "2026-10-02", "From Fri, 25 Dec 2026", "22 Dec 2026"),
        ("2 weeks after 1 jan", "2026-10-02", "From Fri, 1 Jan 2027", "15 Jan 2027"),
        ("tomorrow + 3 days", "2026-10-02", "From Sat, 3 Oct 2026", "6 Oct 2026"),
        ("monday + 3 days", "2026-10-02", "From Mon, 5 Oct 2026", "8 Oct 2026"),
        ("31 jan 2027 + 1 month 1 day", "2026-10-02", "From Sun, 31 Jan 2027", "1 Mar 2027"),
        (
            "1 jan 2027 + 1 year, 2 months and 3 days", "2026-10-02", "From Fri, 1 Jan 2027",
            "4 Mar 2028"
        ),
        ("1 year from now", "2028-02-29", "From Tue, 29 Feb 2028", "28 Feb 2029"),
    ])
    func datesShiftFromAnyDate(query: String, today: String, from: String, result: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(today))
        #expect(answer?.kind == "Dates")
        #expect(answer?.expressionDetail == from)
        #expect(answer?.result == result)
    }

    @Test(arguments: [
        ("days between 1 jan and 1 mar", "1 Jan 2027 → 1 Mar 2027", "59 days", "8 weeks 3 days"),
        (
            "how many days between 1 jan 2026 and 1 mar 2027", "1 Jan 2026 → 1 Mar 2027",
            "424 days", "60 weeks 4 days"
        ),
        ("1 jan to 1 mar", "1 Jan 2027 → 1 Mar 2027", "59 days", "8 weeks 3 days"),
        ("days from 1 jan to 1 mar", "1 Jan 2027 → 1 Mar 2027", "59 days", "8 weeks 3 days"),
        ("1 mar 2027 - 1 jan 2027", "1 Mar 2027 → 1 Jan 2027", "59 days", "8 weeks 3 days"),
        (
            "days between 1 oct 2026 and 2 oct 2026", "1 Oct 2026 → 2 Oct 2026", "1 day",
            "0 weeks 1 day"
        ),
        ("days since 1 jan", "Since 1 Jan 2026", "274 days", "39 weeks 1 day"),
        ("days since 1 jan 2020", "Since 1 Jan 2020", "2,466 days", "352 weeks 2 days"),
        ("how many days since christmas?", "Since 25 Dec 2025", "281 days", "40 weeks 1 day"),
        ("days since 29 feb", "Since 29 Feb 2024", "946 days", "135 weeks 1 day"),
    ])
    func spansCountDaysBetweenDates(
        query: String, expression: String, result: String, detail: String
    ) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.kind == "Dates")
        #expect(answer?.expression == expression)
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == detail)
    }

    @Test(arguments: [
        ("10 business days from today", "From Fri, 2 Oct 2026", "16 Oct 2026"),
        ("in 10 business days", "From Fri, 2 Oct 2026", "16 Oct 2026"),
        ("10 business days ago", "From Fri, 2 Oct 2026", "18 Sep 2026"),
        ("today + 3 business days", "From Fri, 2 Oct 2026", "7 Oct 2026"),
        ("1 business day from today", "From Fri, 2 Oct 2026", "5 Oct 2026"),
        ("1 business day from 3 oct", "From Sat, 3 Oct 2026", "5 Oct 2026"),
        ("1 business day from 4 oct", "From Sun, 4 Oct 2026", "5 Oct 2026"),
        ("1 business day before 3 oct", "From Sat, 3 Oct 2026", "2 Oct 2026"),
        ("2 business days before 5 oct", "From Mon, 5 Oct 2026", "1 Oct 2026"),
        ("5 weekdays after 1 jan 2027", "From Fri, 1 Jan 2027", "8 Jan 2027"),
        ("3 working days before 8 oct", "From Thu, 8 Oct 2026", "5 Oct 2026"),
        ("250 business days from today", "From Fri, 2 Oct 2026", "17 Sep 2027"),
    ])
    func businessDaysSkipWeekends(query: String, from: String, result: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.kind == "Dates")
        #expect(answer?.expressionDetail == from)
        #expect(answer?.result == result)
    }

    @Test(arguments: [
        ("business days until 25 dec", "Until 25 Dec", "60 business days", "84 calendar days"),
        (
            "how many working days until christmas?", "Until 25 Dec", "60 business days",
            "84 calendar days"
        ),
        ("weekdays until 5 oct", "Until 5 Oct", "1 business day", "3 calendar days"),
        ("business days until 2 oct", "Until 2 Oct", "0 business days", "0 calendar days"),
        ("business days since 1 sep", "Since 1 Sep 2026", "23 business days", "31 calendar days"),
        (
            "weekdays between 1 jan and 1 mar", "1 Jan 2027 → 1 Mar 2027", "41 business days",
            "59 calendar days"
        ),
        (
            "business days between 1 oct 2026 and 31 oct 2026", "1 Oct 2026 → 31 Oct 2026",
            "22 business days", "30 calendar days"
        ),
    ])
    func businessDaysAreCounted(
        query: String, expression: String, result: String, detail: String
    ) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.expression == expression)
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == detail)
    }

    @Test(arguments: [
        ("days in march", "Days in March 2026", "Month length", "31 days", "4 weeks 3 days"),
        ("days in feb 2028", "Days in February 2028", "Month length", "29 days", "4 weeks 1 day"),
        (
            "how many days in february?", "Days in February 2026", "Month length", "28 days",
            "4 weeks 0 days"
        ),
        ("days in this month", "Days in October 2026", "Month length", "31 days", "4 weeks 3 days"),
        (
            "days in next month", "Days in November 2026", "Month length", "30 days",
            "4 weeks 2 days"
        ),
        ("days in 2028", "Days in 2028", "Leap year", "366 days", "52 weeks 2 days"),
        ("how many days are in 2027", "Days in 2027", "Common year", "365 days", "52 weeks 1 day"),
        ("days in last year", "Days in 2025", "Common year", "365 days", "52 weeks 1 day"),
        ("days in this year", "Days in 2026", "Common year", "365 days", "52 weeks 1 day"),
    ])
    func monthAndYearLengthsAreCounted(
        query: String, expression: String, detail: String, result: String, weeks: String
    ) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.expression == expression)
        #expect(answer?.expressionDetail == detail)
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == weeks)
    }

    @Test(arguments: [
        ("is 2028 a leap year", "Yes", "366 days"),
        ("is 2100 a leap year?", "No", "365 days"),
        ("leap year 2000", "Yes", "366 days"),
        ("2026 leap year", "No", "365 days"),
    ])
    func leapYearsFollowTheGregorianRule(query: String, result: String, days: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == days)
    }
}
