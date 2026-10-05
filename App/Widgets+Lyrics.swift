import AppCore
import GlassUI

extension Widgets {
    static func widget(of verse: WidgetGrid.Verse) -> WidgetGrid.Widget {
        let name = name(of: lyrics)
        let line = verse.current.flatMap { index in
            verse.lines.indices.contains(index) ? verse.lines[index] : nil
        }
        let spoken =
            switch verse.status {
            case .synced, .plain: line ?? "\(verse.lines.count) lines"
            case .instrumental: "instrumental"
            case .missing: "no lyrics found"
            case .loading: "looking up"
            case .off: "lookup is off"
            }
        return .init(
            id: lyrics, name: name, verse: verse, action: "Show Lyrics",
            spoken: "\(name): \(spoken)")
    }

    static func widget(
        for playing: MusicPlayer.Track, line: (lyric: WidgetGrid.Lyric?, lookingUp: Bool)
    ) -> WidgetGrid.Widget {
        let song = playing.artist.isEmpty ? playing.title : "\(playing.title) by \(playing.artist)"
        return .init(
            id: music, name: name(of: music),
            track: .init(
                title: playing.title, artist: playing.artist, artwork: playing.artwork,
                isPlaying: playing.isPlaying, lyric: line.lyric, lookingUp: line.lookingUp),
            action: "Play / Pause",
            spoken: "\(playing.isPlaying ? "Now playing" : "Paused"): \(song)")
    }

    func mediaWidgets() -> [WidgetGrid.Widget] {
        guard let playing else { return [] }
        let feed = lyricsFeed
        return [
            Self.widget(for: playing, line: feed.tileLine()),
            Self.widget(of: feed.verse(of: playing)),
        ]
    }

    func seek(toLine line: Int) {
        Task { [nowPlaying] in await nowPlaying.seek(toLine: line) }
    }
}
