import Foundation
import Testing

@testable import AppCore

@Suite struct AgendaTests {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3_600

    private let calendar: Calendar
    private let today: Date
    private let now: Date

    init() throws {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar = auckland
        today = auckland.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
        now = today + 12 * Self.hour + 18 * Self.minute
    }

    @Test func onlyTheAgendaWordsOpenIt() {
        for query in ["today", " Agenda ", "TOMORROW"] {
            #expect(Agenda.matches(query))
        }
        for query in ["tod", "today's notes", "calendar", ""] {
            #expect(!Agenda.matches(query))
        }
    }

    @Test func eventsAreGroupedIntoTodayAndTomorrowInStartOrder() throws {
        let review = event("review", at: 14.5)
        let standUp = event("stand-up", at: 9.5)
        let planning = event("planning", at: 34)
        let later = event("later", at: 58)
        let holiday = event("holiday", at: 0, hours: 48, allDay: true)
        let days = Agenda(events: [review, later, planning, standUp, holiday])
            .days(at: now, calendar: calendar)

        let expected = now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        #expect(days.map(\.title) == ["Today · \(expected)", "Tomorrow"])
        #expect(
            days.map { $0.events.map(\.id) } == [
                ["holiday", "stand-up", "review"], ["holiday", "planning"],
            ])
        let span = try #require(Agenda.span(around: now, calendar: calendar))
        #expect(span == DateInterval(start: today, duration: 48 * Self.hour))
    }

    @Test func theNextEventCountsDownAndNamesWhoIsComing() {
        let zoom = meeting("https://zoom.us/j/1")
        let standUp = event("stand-up", at: 9.5, meeting: meeting("https://meet.google.com/a-b-c"))
        let review = event(
            "review", at: 14.5, attendees: ["Hana Kobayashi", "Mei Sato"], meeting: zoom)
        let oneOnOne = event("1:1", at: 16, location: "Room 4B", attendees: ["Mei Sato"])
        let agenda = Agenda(events: [standUp, review, oneOnOne])

        #expect(agenda.next(at: now) == review)
        #expect(agenda.detail(of: standUp, at: now) == "Google Meet · ended")
        #expect(agenda.detail(of: review, at: now) == "Zoom · in 2 h 12 min · Hana, Mei")
        #expect(agenda.detail(of: oneOnOne, at: now) == "Room 4B")
        #expect(
            agenda.detail(of: review, at: today + 14.75 * Self.hour) == "Zoom · now · Hana, Mei")
    }

    @Test func countdownsRoundUpToTheMinute() {
        #expect(Agenda.countdown(to: now + 30, at: now) == "in 1 min")
        #expect(Agenda.countdown(to: now + 45 * Self.minute, at: now) == "in 45 min")
        #expect(Agenda.countdown(to: now + 2 * Self.hour, at: now) == "in 2 h")
        #expect(Agenda.countdown(to: now + 2 * Self.hour + 1, at: now) == "in 2 h 1 min")
        #expect(Agenda.countdown(to: now, at: now) == "now")
    }

    @Test func longGuestListsShowTwoNamesAndACount() {
        let review = event(
            "review", at: 13, attendees: ["Hana Kobayashi", "Mei Sato", "Taro Yamada", "Bo"])
        #expect(Agenda(events: [review]).detail(of: review, at: now) == "in 42 min · Hana, Mei +2")
    }

    @Test func theNextMeetingSkipsEndedAllDayAndLinklessEvents() {
        let ended = event("ended", at: 9.5, meeting: meeting("https://zoom.us/j/1"))
        let allDay = event(
            "offsite", at: 0, hours: 24, allDay: true,
            meeting: meeting(
                "https://zoom.us/j/2"))
        let lunch = event("lunch", at: 12.5)
        let review = event("review", at: 14.5, meeting: meeting("https://zoom.us/j/3"))
        let agenda = Agenda(events: [ended, allDay, lunch, review])

        #expect(agenda.next(at: now) == lunch)
        #expect(agenda.nextMeeting(at: now) == review)
        #expect(Agenda(events: [ended, lunch]).nextMeeting(at: now) == nil)
    }

    private func meeting(_ link: String) -> Meeting? {
        Meeting(in: [link])
    }

    private func event(
        _ id: String, at hour: Double, hours: Double = 0.5, allDay: Bool = false,
        location: String = "", attendees: [String] = [], meeting: Meeting? = nil
    ) -> Agenda.Event {
        let start = today + hour * Self.hour
        return Agenda.Event(
            id: id, title: id, start: start, end: start + hours * Self.hour, isAllDay: allDay,
            location: location, attendees: attendees, meeting: meeting)
    }
}
