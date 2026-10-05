public import Foundation

public struct MenuBarAgenda: Sendable, Equatable {
    private static let joinMinutes = 5
    private static let secondsPerMinute = 60
    private static let titleLimit = 24

    public let event: Agenda.Event
    public let countdown: String
    public let joins: Bool

    public init?(_ agenda: Agenda, at now: Date, calendar: Calendar) {
        guard case .today(let next) = agenda.upNext(at: now, calendar: calendar) else {
            return nil
        }
        event = next
        countdown = Agenda.countdown(to: next.start, at: now, short: true)
        let window = TimeInterval(Self.joinMinutes * Self.secondsPerMinute)
        joins = next.meeting != nil && next.start.timeIntervalSince(now) < window
    }

    public static func shortened(_ title: String, to limit: Int) -> String {
        title.count > limit ? String(title.prefix(limit - 1)) + "…" : title
    }

    public func title(showingEvent: Bool) -> String {
        let name = showingEvent ? Self.shortened(event.title, to: Self.titleLimit) : ""
        let parts = joins ? ["Join", name] : [name, countdown]
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
