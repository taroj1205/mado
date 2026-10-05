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

        public var place: String {
            meeting?.service.rawValue ?? location
        }

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

    public enum UpNext: Sendable, Equatable {
        case today(Event)
        case tomorrow(Event?)
    }

    public struct Heading: Sendable, Equatable {
        public let start: Date
        public let title: String
    }

    public struct Day: Sendable, Equatable {
        public let start: Date
        public let title: String
        public let events: [Event]
    }

    private static let keywords: Set<String> = ["agenda", "today"]
    private static let dayFormat: Date.FormatStyle =
        .dateTime.weekday(.abbreviated).day().month(.abbreviated)
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

    public static func upcoming(at now: Date, calendar: Calendar) -> [Heading] {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return [
            Heading(start: today, title: "Today · \(date(of: today, calendar: calendar))"),
            Heading(start: tomorrow, title: "Tomorrow"),
        ]
    }

    public static func heading(for day: Date, at now: Date, calendar: Calendar) -> Heading {
        let start = calendar.startOfDay(for: day)
        let when = relative(start, at: now, calendar: calendar)
        return Heading(start: start, title: "\(date(of: start, calendar: calendar)) · \(when)")
    }

    public static func date(of day: Date, calendar: Calendar) -> String {
        day.formatted(style(dayFormat, in: calendar))
    }

    public static func span(of headings: [Heading], calendar: Calendar) -> DateInterval? {
        guard let first = headings.first.flatMap({ grid(of: $0.start, calendar: calendar) }),
            let last = headings.last.flatMap({ grid(of: $0.start, calendar: calendar) })
        else { return nil }
        return DateInterval(start: first.start, end: last.end)
    }

    static func relative(_ day: Date, at now: Date, calendar: Calendar) -> String {
        let days =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: day)
            )
            .day ?? 0
        return switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case ..<0: "\(-days) days ago"
        default: "In \(days) days"
        }
    }

    private static func shortName(_ name: String) -> String {
        (try? PersonNameComponents(name))?.formatted(.name(style: .short)) ?? name
    }

    public static func countdown(to start: Date, at now: Date) -> String {
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

    static func style(_ base: Date.FormatStyle, in calendar: Calendar) -> Date.FormatStyle {
        var style = base
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }

    public static func time(of event: Event, listedFrom first: Date, calendar: Calendar) -> String {
        guard !event.isAllDay else { return "All day" }
        let base: Date.FormatStyle =
            event.start < first
            ? .dateTime.weekday(.abbreviated) : .init(date: .omitted, time: .shortened)
        return event.start.formatted(style(base, in: calendar))
    }

    public func days(under headings: [Heading], calendar: Calendar) -> [Day] {
        guard let first = headings.first?.start else { return [] }
        return headings.compactMap { heading in
            guard let end = calendar.date(byAdding: .day, value: 1, to: heading.start) else {
                return nil
            }
            let shown = events.filter { event in
                if event.isAllDay {
                    return event.start < end && event.end > heading.start
                }
                let listed = max(event.start, first)
                return (event.start >= first || event.end > first) && listed >= heading.start
                    && listed < end
            }
            return Day(start: heading.start, title: heading.title, events: shown)
        }
    }

    func events(on day: Date, calendar: Calendar) -> [Event] {
        guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return [] }
        return events.filter { event in
            event.start < end && (event.end > day || event.start >= day)
        }
    }

    public func next(at now: Date) -> Event? {
        events.first { !$0.isAllDay && !$0.hasEnded(at: now) }
    }

    public func upNext(at now: Date, calendar: Calendar) -> UpNext {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
            let after = calendar.date(byAdding: .day, value: 1, to: tomorrow)
        else { return .tomorrow(nil) }
        let timed = events.filter { !$0.isAllDay && !$0.hasEnded(at: now) }
        if let next = timed.first(where: { $0.start < tomorrow }) { return .today(next) }
        return .tomorrow(timed.first { $0.start >= tomorrow && $0.start < after })
    }

    public func nextMeeting(at now: Date) -> Event? {
        events.first { !$0.isAllDay && !$0.hasEnded(at: now) && $0.meeting != nil }
    }

    public func detail(of event: Event, at now: Date) -> String {
        let more: [String] =
            if event.hasEnded(at: now) {
                ["ended"]
            } else if event == next(at: now) {
                [Self.countdown(to: event.start, at: now), Self.names(event.attendees)]
            } else {
                []
            }
        return ([event.place] + more).filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
