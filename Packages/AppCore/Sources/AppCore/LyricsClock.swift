public import Foundation

public struct LyricsClock: Equatable, Sendable {
    private var anchor: TimeInterval
    private var anchoredAt: TimeInterval
    private var isPlaying: Bool

    public init() {
        anchor = 0
        anchoredAt = 0
        isPlaying = false
    }

    public mutating func sync(position: TimeInterval, at now: TimeInterval, isPlaying: Bool) {
        anchor = position
        anchoredAt = now
        self.isPlaying = isPlaying
    }

    public func position(at now: TimeInterval) -> TimeInterval {
        isPlaying ? anchor + max(0, now - anchoredAt) : anchor
    }
}
