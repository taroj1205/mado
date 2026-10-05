import AppCore
import Foundation
import GlassUI

@MainActor
struct LyricsFeed {
    private static let breakText = "♪"
    private static let instrumentalText = "♪ Instrumental"

    private static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    let nowPlaying: NowPlaying

    private var session: LyricsSession {
        nowPlaying.session
    }

    private var moment: Lyrics.Moment? {
        session.moment(at: Self.now)
    }

    private static func resting(_ text: String) -> WidgetGrid.Lyric {
        .init(text: text, progress: 0, remaining: nil)
    }

    func tileLine() -> (lyric: WidgetGrid.Lyric?, lookingUp: Bool) {
        switch session.state {
        case .found(let lyrics) where lyrics.isSynced:
            return (syncedLine(of: lyrics), false)

        case .instrumental:
            return (Self.resting(Self.instrumentalText), false)

        case .loading:
            return (nil, true)

        case .off, .idle, .found, .missing, .failed:
            return (nil, false)
        }
    }

    private func syncedLine(of lyrics: Lyrics) -> WidgetGrid.Lyric {
        guard let moment else { return Self.resting(Self.breakText) }
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
            progress: moment?.progress ?? 0, remaining: moment?.remaining,
            position: status == .off ? nil : session.position(at: Self.now),
            duration: session.length)
    }
}
