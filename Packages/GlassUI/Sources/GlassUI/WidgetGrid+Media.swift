public import Foundation

extension WidgetGrid {
    public enum LyricsStatus: Sendable, Equatable {
        case synced
        case plain
        case instrumental
        case missing
        case loading
        case off
    }

    public struct Lyric: Sendable, Equatable {
        public let text: String
        public let progress: Double
        public let remaining: Double?

        public init(text: String, progress: Double, remaining: Double?) {
            self.text = text
            self.progress = progress
            self.remaining = remaining
        }
    }

    public struct Verse: Sendable, Equatable {
        public let title: String
        public let artist: String
        public let artwork: Data?
        public let isPlaying: Bool
        public let status: LyricsStatus
        public let lines: [String]
        public let current: Int?
        public let progress: Double
        public let remaining: Double?
        public let position: TimeInterval?
        public let duration: TimeInterval?

        public init(
            title: String, artist: String, artwork: Data?, isPlaying: Bool, status: LyricsStatus,
            lines: [String] = [], current: Int? = nil, progress: Double = 0,
            remaining: Double? = nil, position: TimeInterval? = nil,
            duration: TimeInterval? = nil
        ) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
            self.isPlaying = isPlaying
            self.status = status
            self.lines = lines
            self.current = current
            self.progress = progress
            self.remaining = remaining
            self.position = position
            self.duration = duration
        }
    }

    public struct Track: Sendable, Equatable {
        public let title: String
        public let artist: String
        public let artwork: Data?
        public let isPlaying: Bool
        public let lyric: Lyric?
        public let lookingUp: Bool

        public init(
            title: String, artist: String, artwork: Data?, isPlaying: Bool, lyric: Lyric? = nil,
            lookingUp: Bool = false
        ) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
            self.isPlaying = isPlaying
            self.lyric = lyric
            self.lookingUp = lookingUp
        }
    }
}
