import Foundation
import Testing

@testable import SearchKit

@Suite struct TimeZonesTests {
    private static let friday = "2026-10-02T00:00:00Z"

    private static func ask(_ query: String, at now: String = friday) throws -> Calculator.Answer? {
        Calculator.answer(
            for: query, now: try Date(now, strategy: .iso8601),
            local: try #require(TimeZone(identifier: "Pacific/Auckland")))
    }

    @Test func theCanvasExampleFillsTheAnswerCard() throws {
        #expect(
            try Self.ask("3pm tokyo in auckland")
                == Calculator.Answer(
                    kind: "Time zones", expression: "3:00 PM Tokyo", expressionDetail: "Fri 2 Oct",
                    result: "7:00 PM", resultDetail: "Auckland · Fri 2 Oct (same day)"))
    }

    @Test func timeInACityComparesItWithLocalTime() throws {
        #expect(
            try Self.ask("time in london", at: "2026-10-01T22:00:00Z")
                == Calculator.Answer(
                    kind: "Time zones", expression: "Now in London",
                    expressionDetail: "Local 11:00 AM", result: "11:00 PM",
                    resultDetail: "London · Thu 1 Oct (previous day)"))
    }

    @Test(arguments: [
        ("3pm tokyo in auckland", "2026-09-26T00:00:00Z", "6:00 PM"),
        ("3pm tokyo in auckland", "2026-09-28T00:00:00Z", "7:00 PM"),
        ("1am auckland in tokyo", "2026-09-27T00:00:00Z", "10:00 PM"),
        ("9am auckland in tokyo", "2026-09-27T00:00:00Z", "5:00 AM"),
        ("1am new york in london", "2026-03-08T12:00:00Z", "6:00 AM"),
        ("9am new york in london", "2026-03-08T12:00:00Z", "1:00 PM"),
        ("2:30am new york in utc", "2026-03-08T12:00:00Z", "7:30 AM"),
        ("12:30am new york in utc", "2026-11-01T12:00:00Z", "4:30 AM"),
        ("1:30am new york in utc", "2026-11-01T12:00:00Z", "5:30 AM"),
        ("11pm new york in utc", "2026-11-01T12:00:00Z", "4:00 AM"),
    ])
    func daylightSavingSwitchesKeepTheTimeRight(query: String, now: String, result: String) throws {
        #expect(try Self.ask(query, at: now)?.result == result)
    }

    @Test(arguments: [
        ("9pm london in tokyo", "5:00 AM", "Tokyo · Sat 3 Oct (next day)"),
        ("12pm hong kong in los angeles", "9:00 PM", "Los Angeles · Thu 1 Oct (previous day)"),
        ("3pm tokyo", "7:00 PM", "Local time · Fri 2 Oct (same day)"),
        ("15:30 utc to nyc", "11:30 AM", "New York · Fri 2 Oct (same day)"),
        ("9 am osaka -> wellington", "1:00 PM", "Wellington · Fri 2 Oct (same day)"),
        ("12am sf in gmt", "7:00 AM", "GMT · Thu 1 Oct (same day)"),
        ("  3PM Tokyo  IN Auckland ", "7:00 PM", "Auckland · Fri 2 Oct (same day)"),
        ("what time is it in tokyo", "9:00 AM", "Tokyo · Fri 2 Oct (same day)"),
        ("now in nz", "1:00 PM", "New Zealand · Fri 2 Oct (same day)"),
    ])
    func citiesConvert(query: String, result: String, detail: String) throws {
        let answer = try Self.ask(query)
        #expect(answer?.result == result)
        #expect(answer?.resultDetail == detail)
    }

    @Test(arguments: [
        "3 tokyo in auckland", "13pm tokyo", "0am tokyo", "24:00 tokyo", "3:60pm tokyo",
        "3:5pm tokyo", "123pm tokyo", "3pm", "3pm atlantis", "3pm tokyo in atlantis",
        "3pm tokyo in", "time in atlantis", "time in",
    ])
    func unknownTimesAndCitiesHaveNoAnswer(query: String) throws {
        #expect(try Self.ask(query) == nil)
    }
}
