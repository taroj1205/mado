import Foundation
import Testing

@testable import AppCore

@Suite struct MeetingTests {
    @Test func findsZoomMeetAndTeamsLinksWhereverTheEventKeepsThem() throws {
        let zoom = try #require(Meeting(in: ["https://us02web.zoom.us/j/8812345678?pwd=abc"]))
        #expect(zoom.service == .zoom)
        #expect(zoom.url.absoluteString == "https://us02web.zoom.us/j/8812345678?pwd=abc")

        let meet = try #require(
            Meeting(in: ["Room 4B", "Join with Google Meet: meet.google.com/abc-defg-hij"]))
        #expect(meet.service == .meet)
        #expect(meet.url.host() == "meet.google.com")
        #expect(meet.url.path() == "/abc-defg-hij")

        let teams = try #require(
            Meeting(in: [
                "Microsoft Teams meeting. Join: "
                    + "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0"
            ]))
        #expect(teams.service == .teams)
    }

    @Test func skipsLinksInAnInviteThatDoNotJoinTheMeeting() throws {
        let invite = """
            Need help? https://aka.ms/JoinTeamsMeeting
            Meeting options: https://teams.microsoft.com/meetingOptions/?organizerId=1
            Find your local number: https://zoom.us/u/abc
            Help: https://support.google.com/a/users/answer/9282720
            Get Meet: https://meet.google.com/landing
            Join: https://teams.live.com/meet/9876543210
            """
        let meeting = try #require(Meeting(in: [invite]))
        #expect(meeting.url.absoluteString == "https://teams.live.com/meet/9876543210")
        #expect(Meeting(in: ["https://meet.google.com/", "Lunch at the café", ""]) == nil)
    }

    @Test func theFirstTextWithALinkWins() throws {
        let meeting = try #require(
            Meeting(in: ["https://zoom.us/my/hana", "https://meet.google.com/abc-defg-hij"]))
        #expect(meeting.service == .zoom)
    }
}
