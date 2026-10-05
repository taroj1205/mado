public import Foundation

public struct LyricsPresence: Equatable, Sendable {
    public var hideAfter: TimeInterval?
    private var pausedAt: TimeInterval?

    public init(hideAfter: TimeInterval?) {
        self.hideAfter = hideAfter
    }

    public mutating func shows(timed: Bool, playing: Bool, at now: TimeInterval) -> Bool {
        guard timed else {
            pausedAt = playing ? nil : pausedAt ?? now
            return false
        }
        guard !playing else {
            pausedAt = nil
            return true
        }
        let since = pausedAt ?? now
        pausedAt = since
        return hideAfter.map { now - since < $0 } ?? true
    }
}
