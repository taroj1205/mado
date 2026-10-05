import Foundation
import Testing

@testable import AppCore

@Suite struct MenuBarAgendaTests {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3_600

    private let calendar: Calendar
    private let now: Date

    init() throws {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar = auckland
        now =
            auckland.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
            + 12 * Self.hour + 18 * Self.minute
    }

    @Test func theNextEventShowsWithTheTimeLeft() throws {
        let bar = try #require(bar([event("Design review", in: 2 * Self.hour + 12 * Self.minute)]))
        #expect(bar.title(showingEvent: true) == "Design review in 2 h 12 m")
        #expect(bar.title(showingEvent: false) == "in 2 h 12 m")
        #expect(!bar.joins)
    }

    @Test func nothingShowsOnceTheDaysEventsAreOver() {
        let ended = event("Stand-up", in: -2 * Self.hour)
        let tomorrow = event("Planning", in: 14 * Self.hour)
        let allDay = event("Holiday", in: -12 * Self.hour, allDay: true)
        #expect(bar([]) == nil)
        #expect(bar([ended, tomorrow, allDay]) == nil)
    }

    @Test func aMeetingBecomesAJoinButtonUnderFiveMinutes() throws {
        let link = try #require(Meeting(in: ["https://zoom.us/j/123456789"]))
        let soon = event("Design review", in: 4 * Self.minute + 59, meeting: link)
        let notYet = event("Design review", in: 5 * Self.minute, meeting: link)
        let started = event("Design review", in: -Self.minute, meeting: link)
        let noLink = event("Lunch", in: 2 * Self.minute)

        #expect(try #require(bar([soon])).title(showingEvent: true) == "Join Design review")
        #expect(try #require(bar([soon])).title(showingEvent: false) == "Join")
        #expect(try #require(bar([notYet])).joins == false)
        #expect(try #require(bar([started])).joins)
        #expect(try #require(bar([noLink])).title(showingEvent: true) == "Lunch in 2 m")
    }

    @Test func aLongTitleIsCutShort() throws {
        let long = event("Quarterly planning with the whole company", in: Self.hour)
        #expect(
            try #require(bar([long])).title(showingEvent: true) == "Quarterly planning with… in 1 h"
        )
    }

    private func bar(_ events: [Agenda.Event]) -> MenuBarAgenda? {
        MenuBarAgenda(Agenda(events: events), at: now, calendar: calendar)
    }

    private func event(
        _ title: String, in offset: TimeInterval, allDay: Bool = false, meeting: Meeting? = nil
    ) -> Agenda.Event {
        let start = now + offset
        return Agenda.Event(
            id: title, title: title, start: start, end: start + Self.hour, isAllDay: allDay,
            meeting: meeting)
    }
}
