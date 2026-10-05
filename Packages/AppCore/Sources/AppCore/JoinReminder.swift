public import Foundation

public struct JoinReminder: Sendable, Equatable {
    public static let snooze: TimeInterval = 60
    private static let secondsPerMinute: TimeInterval = 60

    private let you: String
    private var dismissed: Set<String>
    private var snoozed: [String: Date]

    public init(you: String) {
        self.you = you
        dismissed = []
        snoozed = [:]
    }

    public func due(in agenda: Agenda, at now: Date, leadMinutes: Int) -> JoinPrompt? {
        let lead = TimeInterval(leadMinutes) * Self.secondsPerMinute
        return agenda.events.lazy
            .filter { event in
                !event.isAllDay && event.start > now && event.start.timeIntervalSince(now) <= lead
                    && !dismissed.contains(event.id) && snoozed[event.id, default: now] <= now
            }
            .compactMap { JoinPrompt($0, at: now, you: you) }
            .first
    }

    public mutating func dismiss(_ event: Agenda.Event) {
        dismissed.insert(event.id)
    }

    public mutating func snooze(_ event: Agenda.Event, at now: Date) {
        snoozed[event.id] = now + Self.snooze
    }
}
