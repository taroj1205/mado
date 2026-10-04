import Foundation
import Testing

@testable import AppCore

@Suite struct RelativeDayTests {
    private static let hour: TimeInterval = 3_600

    @Test func namesTodayAndYesterdayAndDatesBeforeThem() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        let day = try #require(
            calendar.dateInterval(of: .day, for: Date(timeIntervalSince1970: 1_790_000_000)))
        let now = day.start + 9 * Self.hour

        #expect(RelativeDay.title(of: now - Self.hour, now: now, calendar: calendar) == "Today")
        #expect(
            RelativeDay.title(of: now - 10 * Self.hour, now: now, calendar: calendar)
                == "Yesterday")
        let older = RelativeDay.title(of: now - 48 * Self.hour, now: now, calendar: calendar)
        #expect(!["Today", "Yesterday"].contains(older))
    }
}
