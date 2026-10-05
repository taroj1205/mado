public import Foundation

public struct Agenda: Sendable, Equatable {
    public struct Event: Sendable, Equatable {
        public let id: String
        public let title: String
        public let start: Date
        public let end: Date
        public let isAllDay: Bool
        public let location: String
        public let attendees: [String]
        public let meeting: Meeting?

        public init(
            id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
            location: String = "", attendees: [String] = [], meeting: Meeting? = nil
        ) {
            self.id = id
            self.title = title
            self.start = start
            self.end = end
            self.isAllDay = isAllDay
            self.location = location
            self.attendees = attendees
            self.meeting = meeting
        }

        public func hasEnded(at now: Date) -> Bool {
            end <= now
        }
    }

    public struct Day: Sendable, Equatable {
        public let title: String
        public let events: [Event]
    }

    private static let dayCount = 2
    private static let keywords: Set<String> = ["agenda", "today", "tomorrow"]
    private static let namesShown = 2
    private static let minute: TimeInterval = 60
    private static let minutesPerHour = 60

    public let events: [Event]

    public init(events: [Event]) {
        self.events = events.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }

    public static func matches(_ query: String) -> Bool {
        keywords.contains(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    public static func span(around now: Date, calendar: Calendar) -> DateInterval? {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: dayCount, to: start).map { end in
            DateInterval(start: start, end: end)
        }
    }

    private static func shortName(_ name: String) -> String {
        (try? PersonNameComponents(name))?.formatted(.name(style: .short)) ?? name
    }

    static func countdown(to start: Date, at now: Date) -> String {
        guard start > now else { return "now" }
        let minutes = Int((start.timeIntervalSince(now) / minute).rounded(.up))
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: minutesPerHour)
        return switch (hours, rest) {
        case (0, _): "in \(rest) min"
        case (_, 0): "in \(hours) h"
        default: "in \(hours) h \(rest) min"
        }
    }

    private static func names(_ attendees: [String]) -> String {
        let shown = attendees.prefix(namesShown).map(shortName).joined(separator: ", ")
        let others = attendees.count - namesShown
        return others > 0 ? "\(shown) +\(others)" : shown
    }

    public func days(at now: Date, calendar: Calendar) -> [Day] {
        let today = calendar.startOfDay(for: now)
        let date = today.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return zip(0..<Self.dayCount, ["Today · \(date)", "Tomorrow"]).compactMap { offset, title in
            guard let start = calendar.date(byAdding: .day, value: offset, to: today),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else { return nil }
            let shown = events.filter { $0.start < end && ($0.end > start || $0.start >= start) }
            return Day(title: title, events: shown)
        }
    }

    public func next(at now: Date) -> Event? {
        events.first { !$0.isAllDay && !$0.hasEnded(at: now) }
    }

    public func nextMeeting(at now: Date) -> Event? {
        events.first { !$0.isAllDay && !$0.hasEnded(at: now) && $0.meeting != nil }
    }

    public func detail(of event: Event, at now: Date) -> String {
        let place = event.meeting?.service.rawValue ?? event.location
        let more: [String] =
            if event.hasEnded(at: now) {
                ["ended"]
            } else if event == next(at: now) {
                [Self.countdown(to: event.start, at: now), Self.names(event.attendees)]
            } else {
                []
            }
        return ([place] + more).filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
