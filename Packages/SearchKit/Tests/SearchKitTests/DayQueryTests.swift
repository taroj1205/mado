import Foundation
import Testing

@testable import SearchKit

@Suite struct DayQueryTests {
    private let calendar: Calendar
    private let now: Date

    init() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar = gregorian
        now = try #require(
            gregorian.date(from: DateComponents(year: 2_026, month: 10, day: 5, hour: 18)))
    }

    @Test(arguments: [
        ("today", "2026-10-05"),
        (" Tomorrow ", "2026-10-06"),
        ("yesterday", "2026-10-04"),
        ("in 2 days", "2026-10-07"),
        ("in 2 weeks", "2026-10-19"),
        ("3 days ago", "2026-10-02"),
        ("45 days from today", "2026-11-19"),
        ("1 month later", "2026-11-05"),
        ("monday", "2026-10-05"),
        ("next monday", "2026-10-12"),
        ("next fri", "2026-10-09"),
        ("this wednesday", "2026-10-07"),
        ("25 dec", "2026-12-25"),
        ("dec 25th", "2026-12-25"),
        ("days until christmas", "2026-12-25"),
        ("3 oct", "2027-10-03"),
        ("3 oct 2026", "2026-10-03"),
        ("days until 1 jan", "2027-01-01"),
        ("29 feb", "2028-02-29"),
    ])
    func namedRelativeAndCalendarDaysResolve(query: String, expected: String) throws {
        let day = try #require(DayQuery.day(in: query, now: now, calendar: calendar))
        let parts = expected.split(separator: "-").compactMap { Int($0) }
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: day)
        #expect([components.year, components.month, components.day] == parts.map(Optional.some))
        #expect(components.hour == 0)
    }

    @Test(arguments: [
        "mon", "monitor", "calendar", "5 min", "in 2", "2 days", "30 feb 2026", "next", "agenda",
        "days until 3 oct 2026", "christmas",
    ])
    func otherSearchesAreNotDays(query: String) {
        #expect(DayQuery.day(in: query, now: now, calendar: calendar) == nil)
    }
}
