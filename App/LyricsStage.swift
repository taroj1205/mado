import AppCore
import AppKit
import GlassUI

@MainActor
final class LyricsStage: NSObject {
    let nowPlaying: NowPlaying
    let float = LyricsFloat()
    let line = LyricsMenuBarLine()
    let bar = LyricsBar()
    let modules: () -> ModuleManager?
    let statusItem: () -> NSStatusItem?
    let restoreIcon: () -> Void
    var menu: NSMenu?
    var isCardOpen = false
    var surroundings: LyricsSurroundings?
    var survey: Task<Void, Never>?
    private(set) var settings = LyricsSettings()
    private var presence = LyricsPresence(hideAfter: nil)

    private var feed: LyricsFeed {
        LyricsFeed(nowPlaying: nowPlaying)
    }

    private var screen: NSScreen? {
        settings.screen.screen ?? NSScreen.main
    }

    var hostsMenuBar: Bool {
        settings.pin == .menuBar && statusItem()?.isVisible == true
    }

    init(
        nowPlaying: NowPlaying, modules: @escaping () -> ModuleManager?,
        statusItem: @escaping () -> NSStatusItem?, restoreIcon: @escaping () -> Void
    ) {
        self.nowPlaying = nowPlaying
        self.modules = modules
        self.statusItem = statusItem
        self.restoreIcon = restoreIcon
        super.init()
        float.onControl = { [weak self] control in self?.perform(control) }
        float.onMove = { [weak self] corner, screen in self?.moved(to: corner, on: screen) }
        float.onDismiss = { [weak self] in self?.isCardOpen = false }
    }

    func apply(_ next: LyricsSettings) {
        settings = next
        presence.hideAfter = next.hideDelay.seconds
        syncSurvey()
        if next.isActive {
            nowPlaying.start(.stage)
        } else {
            nowPlaying.stop(.stage)
        }
        update()
    }

    func update() {
        guard settings.isActive else {
            presence.reset()
            hide()
            return
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        guard let verse = nowPlaying.track.map(feed.verse(of:)),
            presence.shows(timed: verse.status == .synced, playing: verse.isPlaying, at: uptime)
        else {
            hide()
            return
        }
        show(verse)
    }

    private func show(_ verse: WidgetGrid.Verse) {
        if hostsMenuBar {
            if float.isShown, !isCardOpen {
                float.hide(animated: false)
            }
            showMenuBarLine(verse)
            return
        }
        hideMenuBarLine()
        guard let pin = settings.pin, let screen else { return }
        if showBar(verse, pin: pin, on: screen) { return }
        let place: LyricsPlace =
            switch pin {
            case .corner: .corner(settings.corner)
            case .desktop: .desktop
            case .island, .menuBar, .dock, .menus: .island
            }
        float.show(
            verse, place: place, look: settings.look, on: screen,
            hidesInSharing: settings.hidesInSharing)
    }

    func hide() {
        float.hide(animated: true)
        bar.hide(animated: true)
        isCardOpen = false
        hideMenuBarLine()
    }

    private func perform(_ control: LyricsControl) {
        let action: MusicPlayer.Control =
            switch control {
            case .previous: .previous
            case .playPause: .playPause
            case .next: .next
            }
        Task { [nowPlaying] in await nowPlaying.perform(action) }
    }

    private func moved(to corner: LyricsCorner, on screen: NSScreen) {
        var next = LyricsSettings.load(from: modules())
        next.corner = corner
        if let display = LauncherScreen.display(of: screen) {
            next.screen = display
        }
        next.save(to: modules())
        settings = next
        update()
    }
}
