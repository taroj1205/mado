import Foundation
import Testing

@testable import SearchKit

@Suite struct TimeMathTests {
    private static let today = "2026-10-02"

    private static func date(_ text: String) throws -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 14)
        return try #require(calendar.date(from: components))
    }

    @Test(arguments: [
        (
            "9:15am to 5:40pm",
            Calculator.Answer(
                kind: "Time", expression: "9:15 AM → 5:40 PM", expressionDetail: "Hours between",
                result: "8 h 25 min", resultDetail: "8.42 hours · 505 minutes")
        ),
        (
            "2h 30m + 45m",
            Calculator.Answer(
                kind: "Duration", expression: "2h 30m + 45m", expressionDetail: "Duration",
                result: "3 h 15 min", resultDetail: "3.25 hours · 195 minutes")
        ),
        (
            "9:30am + 2h 45m",
            Calculator.Answer(
                kind: "Time", expression: "9:30 AM + 2 h 45 min", expressionDetail: "Time of day",
                result: "12:15 PM", resultDetail: "Same day")
        ),
        (
            "45 days from today",
            Calculator.Answer(
                kind: "Dates", expression: "45 days from today",
                expressionDetail: "From Fri, 2 Oct 2026", result: "16 Nov 2026",
                resultDetail: "Monday")
        ),
        (
            "days until 25 dec",
            Calculator.Answer(
                kind: "Dates", expression: "Until 25 Dec", expressionDetail: "Fri, 25 Dec 2026",
                result: "84 days", resultDetail: "12 weeks 0 days")
        ),
    ])
    func theCanvasExamplesFillTheAnswerCard(query: String, answer: Calculator.Answer) throws {
        #expect(Calculator.answer(for: query, now: try Self.date(Self.today)) == answer)
    }

    @Test(arguments: [
        ("10pm to 6am", "8 h", "Hours between (overnight)"),
        ("from 9am - 5pm", "8 h", "Hours between"),
        ("12am until 12pm", "12 h", "Hours between"),
        ("17:00 to 9:30", "16 h 30 min", "Hours between (overnight)"),
        ("12:01am to 11:59pm", "23 h 58 min", "Hours between"),
    ])
    func hoursBetweenWrapPastMidnight(query: String, result: String, detail: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.result == result)
        #expect(answer?.expressionDetail == detail)
    }

    @Test(arguments: [
        ("11pm + 2h", "1:00 AM", "Next day"),
        ("1am - 2h", "11:00 PM", "Previous day"),
        ("12:30am - 30 mins", "12:00 AM", "Same day"),
        ("9am - 90s", "8:58 AM", "Same day"),
        ("12am - 1s", "11:59 PM", "Previous day"),
        ("9am + 3d", "9:00 AM", "3 days later"),
        ("9am - 2 days 1 hour", "8:00 AM", "2 days earlier"),
        ("2h 30m in minutes", "150 minutes", "2 h 30 min"),
        ("1 day as hours", "24 hours", "1 d"),
        ("100 seconds to minutes", "1.667 minutes", "1 min 40 s"),
        ("90m - 2h in minutes", "-30 minutes", "−30 min"),
        ("1h 30m x 3", "4 h 30 min", "4.5 hours · 270 minutes"),
        ("90m - 2h", "−30 min", "-0.5 hours · -30 minutes"),
        ("2h30m + 1d", "1 d 2 h 30 min", "26.5 hours · 1,590 minutes"),
        ("1.5h + 30m", "2 h", "2 hours · 120 minutes"),
    ])
    func durationsAddUp(query: String, result: String, detail: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == detail)
    }

    @Test(arguments: [
        ("1 month from today", "2026-01-31", "28 Feb 2026"),
        ("1 month from today", "2028-01-31", "29 Feb 2028"),
        ("1 year from now", "2028-02-29", "28 Feb 2029"),
        ("45 days from today", "2026-12-31", "14 Feb 2027"),
        ("1 day later", "2028-02-28", "29 Feb 2028"),
        ("in 3 weeks", "2026-10-02", "23 Oct 2026"),
        ("10 days ago", "2026-03-05", "23 Feb 2026"),
        ("10 days ago", "2028-03-05", "24 Feb 2028"),
    ])
    func datesFollowTheCalendar(query: String, today: String, result: String) throws {
        #expect(Calculator.answer(for: query, now: try Self.date(today))?.result == result)
    }

    @Test(arguments: [
        ("days until 29 feb", "Tue, 29 Feb 2028", "515 days"),
        ("days until 1 oct", "Fri, 1 Oct 2027", "364 days"),
        ("days to 3 oct", "Sat, 3 Oct 2026", "1 day"),
        ("days until 2 oct", "Fri, 2 Oct 2026", "0 days"),
        ("how many days until dec 25th?", "Fri, 25 Dec 2026", "84 days"),
        ("days till christmas", "Fri, 25 Dec 2026", "84 days"),
        ("days until new year", "Fri, 1 Jan 2027", "91 days"),
        ("until 1 march 2027", "Mon, 1 Mar 2027", "150 days"),
    ])
    func countdownsRollToTheNextDate(query: String, date: String, result: String) throws {
        let answer = Calculator.answer(for: query, now: try Self.date(Self.today))
        #expect(answer?.expressionDetail == date)
        #expect(answer?.result == result)
    }

    @Test(arguments: [
        ("UTC", "From Fri, 2 Oct 2026", "16 Nov 2026"),
        ("Pacific/Kiritimati", "From Sat, 3 Oct 2026", "17 Nov 2026"),
    ])
    func datesUseTheLocalTimeZone(zone: String, detail: String, result: String) throws {
        let noonUTC = Date(timeIntervalSince1970: 1_790_942_400)
        let local = try #require(TimeZone(identifier: zone))
        let answer = Calculator.answer(for: "45 days from today", now: noonUTC, local: local)
        #expect(answer?.expressionDetail == detail)
        #expect(answer?.result == result)
    }

    @Test(arguments: [
        "9am", "45min", "2h 30m", "13pm to 5pm", "0am to 5pm", "9:60am to 5pm", "24:00 to 1:00",
        "9 to 5", "2h + ", "5 parsecs + 2h", "45 days", "days until 30 feb 2028",
        "days until 1 jan 2020", "days until 32 dec", "days until 25 de",
        "9am + 1" + String(repeating: "0", count: 400) + "d",
        "in 99999999999999999999 days", "9am + 9223372036854775807s",
        "1s - 9223372036854775808s",
    ])
    func invalidTimesHaveNoAnswer(query: String) throws {
        #expect(Calculator.answer(for: query, now: try Self.date(Self.today)) == nil)
    }
}
