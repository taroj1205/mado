public import Foundation

public struct JoinPrompt: Sendable, Equatable {
    private static let namesShown = 2

    public let event: Agenda.Event
    public let meeting: Meeting
    public let detail: String
    public let initials: [String]
    public let attendees: String

    public init?(_ event: Agenda.Event, at now: Date, you: String) {
        guard let found = event.meeting else { return nil }
        self.event = event
        meeting = found
        detail = ["Starts \(Agenda.countdown(to: event.start, at: now))", event.hours, event.place]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        initials =
            event.attendees.isEmpty
            ? [] : (event.attendees.prefix(Self.namesShown) + [you]).map(Self.initials)
        attendees = Self.names(event.attendees)
    }

    private static func initials(of name: String) -> String {
        let components = try? PersonNameComponents(name)
        return components?.formatted(.name(style: .abbreviated)).uppercased()
            ?? String(name.prefix(1)).uppercased()
    }

    private static func names(_ attendees: [String]) -> String {
        guard !attendees.isEmpty else { return "" }
        let others = attendees.count - namesShown
        let parts =
            attendees.prefix(namesShown).map(Agenda.shortName)
            + (others > 0 ? ["\(others) more"] : []) + ["you"]
        return parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "")
    }
}
