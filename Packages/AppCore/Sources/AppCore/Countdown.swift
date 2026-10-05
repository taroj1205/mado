public import Foundation

public struct Countdown: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public private(set) var length: TimeInterval
    public private(set) var endsAt: Date?
    public private(set) var isAnnounced = false
    private var paused: TimeInterval

    public init(
        name: String, length: TimeInterval, startingAt start: Date, id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.length = length
        endsAt = start + length
        paused = length
    }

    public func remaining(at now: Date) -> TimeInterval {
        endsAt.map { max(0, $0.timeIntervalSince(now)) } ?? paused
    }

    public func isRunning(at now: Date) -> Bool {
        endsAt != nil && remaining(at: now) > 0
    }

    public func isFinished(at now: Date) -> Bool {
        remaining(at: now) == 0
    }

    public func fraction(at now: Date) -> Double {
        length > 0 ? remaining(at: now) / length : 0
    }

    public mutating func pause(at now: Date) {
        guard isRunning(at: now) else { return }
        paused = remaining(at: now)
        endsAt = nil
    }

    public mutating func resume(at now: Date) {
        guard endsAt == nil, paused > 0 else { return }
        endsAt = now + paused
    }

    public mutating func restart(at now: Date) {
        endsAt = now + length
        paused = length
        isAnnounced = false
    }

    public mutating func extend(by extra: TimeInterval, at now: Date) {
        if isFinished(at: now) {
            length = extra
            restart(at: now)
        } else if let end = endsAt {
            endsAt = end + extra
            length += extra
        } else {
            paused += extra
            length += extra
        }
    }

    mutating func settle(at now: Date) -> Bool {
        guard endsAt != nil, isFinished(at: now), !isAnnounced else { return false }
        endsAt = nil
        paused = 0
        isAnnounced = true
        return true
    }
}
