import Foundation
import Testing

@testable import AppCore

@Suite struct JoinReminderTests {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3_600
    private static let lead = 2
    private static let you = "Taro Yamada"

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let zoom = Meeting(in: ["https://zoom.us/j/123456789"])

    @Test func aMeetingShowsOnlyOnceItIsWithinTheLeadTime() {
        let reminder = JoinReminder(you: Self.you)
        #expect(due(reminder, [event("Review", in: 2 * Self.minute + 1)]) == nil)
        #expect(due(reminder, [event("Review", in: 2 * Self.minute)])?.event.title == "Review")
        #expect(due(reminder, [event("Review", in: 1)])?.event.title == "Review")
        #expect(due(reminder, [event("Review", in: 0)]) == nil)
        #expect(due(reminder, [event("Review", in: -Self.minute)]) == nil)
    }

    @Test func theLeadTimeComesFromTheSetting() {
        let review = event("Review", in: 4 * Self.minute)
        #expect(due(JoinReminder(you: Self.you), [review], lead: 2) == nil)
        #expect(due(JoinReminder(you: Self.you), [review], lead: 5)?.event.title == "Review")
    }

    @Test func onlyTimedMeetingsWithALinkQualify() {
        let reminder = JoinReminder(you: Self.you)
        let lunch = event("Lunch", in: Self.minute, meeting: nil)
        let holiday = event("Holiday", in: Self.minute, allDay: true)
        #expect(due(reminder, [lunch, holiday]) == nil)
        #expect(due(reminder, [lunch, holiday, event("Review", in: Self.minute)]) != nil)
    }

    @Test func theEarliestMeetingShowsFirst() {
        let later = event("Later", in: 90)
        let sooner = event("Sooner", in: 30)
        #expect(due(JoinReminder(you: Self.you), [later, sooner])?.event.title == "Sooner")
    }

    @Test func dismissingHidesThatMeetingOnly() {
        var reminder = JoinReminder(you: Self.you)
        let first = event("First", in: 30)
        let second = event("Second", in: 90)
        reminder.dismiss(first)
        #expect(due(reminder, [first, second])?.event.title == "Second")
        #expect(due(reminder, [first]) == nil)
    }

    @Test func snoozingBringsTheMeetingBackAfterAMinute() {
        var reminder = JoinReminder(you: Self.you)
        let review = event("Review", in: 100)
        reminder.snooze(review, at: now)
        #expect(due(reminder, [review]) == nil)
        #expect(due(reminder, [review], at: now + JoinReminder.snooze - 1) == nil)
        #expect(due(reminder, [review], at: now + JoinReminder.snooze)?.event.title == "Review")
    }

    @Test func aSnoozeLastingPastTheStartEndsTheReminder() {
        var reminder = JoinReminder(you: Self.you)
        let review = event("Review", in: 40)
        reminder.snooze(review, at: now)
        #expect(due(reminder, [review], at: now + JoinReminder.snooze) == nil)
    }

    @Test func aMovedMeetingIsAskedAgain() {
        var reminder = JoinReminder(you: Self.you)
        reminder.dismiss(event("Review", in: 30))
        let moved = Agenda.Event(
            id: "Review@moved", title: "Review", start: now + 40, end: now + Self.hour,
            meeting: zoom)
        #expect(due(reminder, [moved]) != nil)
    }

    @Test func thePromptDescribesTheMeeting() throws {
        let review = Agenda.Event(
            id: "review", title: "Design review", start: now + 2 * Self.minute - 5,
            end: now + Self.hour, attendees: ["Hana Kato", "Mei Sato", "Ren Ito"], meeting: zoom)
        let prompt = try #require(JoinPrompt(review, at: now, you: Self.you))
        #expect(prompt.detail.hasPrefix("Starts in 2 min · "))
        #expect(prompt.detail.hasSuffix(" · Zoom"))
        #expect(prompt.initials == ["HK", "MS", "TY"])
        #expect(prompt.attendees == "Hana, Mei, 1 more and you")
    }

    @Test func attendeeNamesReadNaturally() {
        let names = { (attendees: [String]) -> String? in
            JoinPrompt(
                Agenda.Event(
                    id: "e", title: "e", start: now + 30, end: now + Self.hour,
                    attendees: attendees, meeting: zoom), at: now, you: Self.you)?.attendees
        }
        #expect(names([])?.isEmpty == true)
        #expect(names(["Hana Kato"]) == "Hana and you")
        #expect(names(["Hana Kato", "Mei Sato"]) == "Hana, Mei and you")
        #expect(
            names(["Hana Kato", "Mei Sato", "Ren Ito", "Aki Mori"]) == "Hana, Mei, 2 more and you")
    }

    private func due(
        _ reminder: JoinReminder, _ events: [Agenda.Event], lead: Int = Self.lead,
        at time: Date? = nil
    ) -> JoinPrompt? {
        reminder.due(in: Agenda(events: events), at: time ?? now, leadMinutes: lead)
    }

    private func event(
        _ title: String, in offset: TimeInterval, allDay: Bool = false,
        meeting: Meeting? = Meeting(in: ["https://zoom.us/j/123456789"])
    ) -> Agenda.Event {
        Agenda.Event(
            id: title, title: title, start: now + offset, end: now + offset + Self.hour,
            isAllDay: allDay, meeting: meeting)
    }
}
