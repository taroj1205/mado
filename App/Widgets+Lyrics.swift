import AppCore
import GlassUI
import os

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
            id: lyrics, name: name, verse: verse, action: "Play / Pause",
            spoken: "\(name): \(spoken)")
    }

    static func widget(
        for playing: MusicPlayer.Track, lyric: WidgetGrid.Lyric?
    ) -> WidgetGrid.Widget {
        let song = playing.artist.isEmpty ? playing.title : "\(playing.title) by \(playing.artist)"
        return .init(
            id: music, name: name(of: music),
            track: .init(
                title: playing.title, artist: playing.artist, artwork: playing.artwork,
                isPlaying: playing.isPlaying, lyric: lyric),
            action: "Play / Pause",
            spoken: "\(playing.isPlaying ? "Now playing" : "Paused"): \(song)")
    }

    func mediaWidgets() -> [WidgetGrid.Widget] {
        guard let playing else { return [] }
        return [
            Self.widget(for: playing, lyric: lyricsFeed.lyric()),
            Self.widget(of: lyricsFeed.verse(of: playing)),
        ]
    }

    func seek(toLine line: Int, in view: LauncherView) {
        guard let start = lyricsFeed.start(ofLine: line), playing != nil else { return }
        Task { [weak self, weak view] in
            do {
                try await Self.player.seek(to: start)
                guard let self, let view else { return }
                lyricsFeed.moved(to: start, isPlaying: playing?.isPlaying ?? false)
                refresh(view)
            } catch {
                Self.logger.error("Seek failed: \(error, privacy: .private)")
            }
        }
    }

    func listen(in view: LauncherView) {
        lyricsFeed.onChange = { [weak self, weak view] in
            guard let self, let view else { return }
            refresh(view)
        }
        listening = Task { [weak self, weak view] in
            while !Task.isCancelled {
                let found = await Self.player.track()
                guard !Task.isCancelled, let self, let view else { return }
                let position = lyricsEnabled ? await Self.player.position() : nil
                playing = found
                lyricsFeed.update(found, position: position, enabled: lyricsEnabled)
                refresh(view)
                try? await Task.sleep(for: .seconds(Self.listenSeconds))
            }
        }
        following = Task { [weak self, weak view] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.followSeconds))
                guard !Task.isCancelled, let self, let view else { return }
                if lyricsFeed.advance() { refresh(view) }
            }
        }
    }
}
