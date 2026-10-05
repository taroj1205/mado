import AppCore
import Foundation
import GlassUI

@MainActor
final class LyricsFeed {
    private static let breakText = "♪"

    private static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private let session = LyricsSession()
    private var shown: Int?

    var onChange: (() -> Void)? {
        get { session.onChange }
        set { session.onChange = newValue }
    }

    private var moment: Lyrics.Moment? {
        session.moment(at: Self.now)
    }

    func update(_ track: MusicPlayer.Track?, position: TimeInterval?, enabled: Bool) {
        session.update(track, position: position, enabled: enabled, at: Self.now)
    }

    func advance() -> Bool {
        let line = moment?.index
        defer { shown = line }
        return line != shown
    }

    func lyric() -> WidgetGrid.Lyric? {
        guard let lyrics = session.lyrics, lyrics.isSynced, let moment else { return nil }
        let text = lyrics.lines[moment.index].text
        return .init(
            text: text.isEmpty ? Self.breakText : text, progress: moment.progress,
            remaining: moment.remaining)
    }

    func verse(of track: MusicPlayer.Track) -> WidgetGrid.Verse {
        let status: WidgetGrid.LyricsStatus =
            switch session.state {
            case .off: .off
            case .idle, .loading: .loading
            case .found(let found): found.isSynced ? .synced : .plain
            case .instrumental: .instrumental
            case .missing, .failed: .missing
            }
        return .init(
            title: track.title, artist: track.artist, artwork: track.artwork,
            isPlaying: track.isPlaying, status: status,
            lines: session.lyrics?.lines.map(\.text) ?? [], current: moment?.index,
            progress: moment?.progress ?? 0, remaining: moment?.remaining)
    }

    func start(ofLine line: Int) -> TimeInterval? {
        session.start(ofLine: line)
    }

    func moved(to position: TimeInterval, isPlaying: Bool) {
        session.moved(to: position, isPlaying: isPlaying, at: Self.now)
    }
}
