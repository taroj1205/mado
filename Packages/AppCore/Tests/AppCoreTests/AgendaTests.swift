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
        for query in ["today", " Agenda ", "TODAY"] {
            #expect(Agenda.matches(query))
        }
        for query in ["tod", "today's notes", "calendar", "tomorrow", ""] {
            #expect(!Agenda.matches(query))
        }
    }

    @Test func eventsAreGroupedIntoTodayAndTomorrowInStartOrder() throws {
        let review = event("review", at: 14.5)
        let standUp = event("stand-up", at: 9.5)
        let planning = event("planning", at: 34)
        let later = event("later", at: 58)
        let holiday = event("holiday", at: 0, hours: 48, allDay: true)
        let overnight = event("overnight", at: 23, hours: 2)
        let lastNight = event("last-night", at: -1, hours: 3)
        let headings = Agenda.upcoming(at: now, calendar: calendar)
        let days = Agenda(events: [review, later, planning, standUp, holiday, overnight, lastNight])
            .days(under: headings, calendar: calendar)

        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        style.timeZone = calendar.timeZone
        let expected = now.formatted(style)
        #expect(days.map(\.title) == ["Today · \(expected)", "Tomorrow"])
        #expect(
            days.map { $0.events.map(\.id) } == [
                ["last-night", "holiday", "stand-up", "review", "overnight"],
                ["holiday", "planning"],
            ])
        let span = try #require(Agenda.span(of: headings, calendar: calendar))
        #expect(span.contains(today) && span.contains(today + 47 * Self.hour))
    }

    @Test func aSingleDayListsOnlyItsOwnEventsAndSaysHowFarAwayItIs() throws {
        let tonight = event("tonight", at: 47, hours: 2)
        let morning = event("morning", at: 57)
        let ended = event("ended", at: 30)
        let after = event("after", at: 73)
        let day = try #require(calendar.date(byAdding: .day, value: 2, to: today))
        let heading = Agenda.heading(for: day + 9 * Self.hour, at: now, calendar: calendar)
        let days = Agenda(events: [after, morning, ended, tonight])
            .days(under: [heading], calendar: calendar)
        var weekday = Date.FormatStyle.dateTime.weekday(.abbreviated)
        weekday.timeZone = calendar.timeZone

        #expect(heading.start == day)
        #expect(heading.title == "\(Agenda.date(of: day, calendar: calendar)) · In 2 days")
        #expect(days.map { $0.events.map(\.id) } == [["tonight", "morning"]])
        #expect(
            Agenda.time(of: tonight, listedFrom: day, calendar: calendar)
                == tonight.start.formatted(weekday))
        let yesterday = Agenda.heading(for: today - Self.hour, at: now, calendar: calendar)
        #expect(yesterday.title.hasSuffix(" · Yesterday"))
    }

    @Test func theMonthGridStartsOnTheFirstWeekdayAndMarksTheFocusedDay() throws {
        var mondays = calendar
        mondays.firstWeekday = 2
        let focus = try #require(mondays.date(byAdding: .day, value: 5, to: today))
        let review = event("review", at: 14.5)
        let party = Agenda.Event(
            id: "party", title: "party", start: focus + 19 * Self.hour,
            end: focus + 21 * Self.hour)
        let month = try #require(
            Agenda(events: [review, party]).month(showing: focus, at: now, calendar: mondays))

        var style = Date.FormatStyle.dateTime.month(.wide)
        style.timeZone = mondays.timeZone
        #expect(month.name == focus.formatted(style))
        #expect(month.weekdays.first == mondays.shortStandaloneWeekdaySymbols[1])
        #expect(month.initials.first == mondays.veryShortStandaloneWeekdaySymbols[1])
        #expect(month.initials.count == month.weekdays.count)
        #expect(month.days.count == 35)
        #expect(month.days.first?.number == "31")
        #expect(month.days.first?.isInMonth == false)
        #expect(month.days.last?.number == "4")
        let focused = month.days[month.focused]
        #expect(focused.start == focus)
        #expect(focused.query == "27 sep 2026")
        #expect(focused.isWeekend)
        #expect(focused.events.map(\.id) == ["party"])
        #expect(month.days.filter(\.isToday).map(\.start) == [today])
        #expect(month.days.first(where: \.isToday)?.events.map(\.id) == ["review"])
    }

    @Test func eventsCarriedOverFromAnEarlierDayShowTheDayTheyStarted() {
        var weekday = Date.FormatStyle.dateTime.weekday(.abbreviated)
        weekday.timeZone = calendar.timeZone
        var clock = Date.FormatStyle(date: .omitted, time: .shortened)
        clock.timeZone = calendar.timeZone
        let lastNight = event("last-night", at: -1, hours: 3)
        let review = event("review", at: 14.5)
        let tonight = event("tonight", at: 23)
        let holiday = event("holiday", at: -24, hours: 72, allDay: true)

        #expect(
            Agenda.time(of: lastNight, listedFrom: today, calendar: calendar)
                == lastNight.start.formatted(weekday))
        #expect(
            Agenda.time(of: review, listedFrom: today, calendar: calendar)
                == review.start.formatted(clock))
        #expect(
            Agenda.time(of: tonight, listedFrom: today, calendar: calendar)
                == tonight.start.formatted(clock))
        #expect(Agenda.time(of: holiday, listedFrom: today, calendar: calendar) == "All day")
        #expect(lastNight.start.formatted(weekday) != now.formatted(weekday))
    }

    @Test func theNextEventCountsDownAndNamesWhoIsComing() {
        let zoom = meeting("https://zoom.us/j/1")
        let standUp = event(
            "stand-up", at: 9.5, meeting: meeting("https://meet.google.com/abc-defg-hij"))
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

    @Test func upNextIsTheNextTimedEventTodayOrElseTomorrowsFirst() {
        let ended = event("ended", at: 9.5)
        let holiday = event("holiday", at: 0, hours: 48, allDay: true)
        let review = event("review", at: 14.5, meeting: meeting("https://zoom.us/j/1"))
        let standUp = event("stand-up", at: 34)
        let later = event("later", at: 58)

        #expect(
            Agenda(events: [ended, holiday, review, standUp]).upNext(at: now, calendar: calendar)
                == .today(review))
        #expect(
            Agenda(events: [ended, holiday, standUp]).upNext(at: now, calendar: calendar)
                == .tomorrow(standUp))
        #expect(
            Agenda(events: [ended, later]).upNext(at: now, calendar: calendar) == .tomorrow(nil))
        #expect(review.place == "Zoom")
        #expect(event("1:1", at: 16, location: "Room 4B").place == "Room 4B")
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
