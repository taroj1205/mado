import AppCore
import AppKit
import GlassUI

extension AppDelegate {
    func connectLyrics() {
        nowPlaying.onChange = { [weak self] in
            self?.widgets.refreshWhileShown()
            self?.lyricsStage.update()
        }
        launcherView.onPinLyrics = { [weak self] pin in
            guard let self else { return }
            var settings = LyricsSettings.load(from: modules)
            settings.pin = pin
            settings.save(to: modules)
            applyLyricsSettings()
        }
        applyLyricsSettings()
    }

    func applyLyricsSettings() {
        let settings = LyricsSettings.load(from: modules)
        nowPlaying.players = settings.players
        nowPlaying.lookup = settings.lookup
        launcherView.pinnedLyrics = settings.pin
        lyricsStage.apply(settings)
    }
}
