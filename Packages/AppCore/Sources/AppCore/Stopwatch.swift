public import Foundation

public struct Stopwatch: Codable, Equatable, Sendable {
    private var startedAt: Date?
    private var banked: TimeInterval = 0

    public var isIdle: Bool {
        startedAt == nil && banked == 0
    }

    public var isRunning: Bool {
        startedAt != nil
    }

    public func elapsed(at now: Date) -> TimeInterval {
        banked + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    public mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func pause(at now: Date) {
        banked = elapsed(at: now)
        startedAt = nil
    }

    public mutating func reset() {
        self = Self()
    }
}
