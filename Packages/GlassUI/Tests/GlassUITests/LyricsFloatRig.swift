import AppKit

@testable import GlassUI

@MainActor
final class LyricsFloatRig {
    static let lines = [
        "The harbour breathes in slow", "Every rope remembers where it’s tied", "",
        "Tell me what the tide forgot",
    ]
    static let reach: CGFloat = 100_000
    static let away = NSPoint(x: -reach, y: -reach)
    static let progress = 0.37
    static let remaining = 2.5
    static let synced = song(.synced, current: 1, playing: true)

    let float = LyricsFloat()
    var point = away
    var buttons = 0
    var clock = ContinuousClock.now
    var look = LyricsLook.line
    var verse = synced
    var hidesInSharing = true
    var controls: [LyricsControl] = []
    var moves: [(LyricsCorner, NSScreen)] = []
    var dismissals = 0

    var screen: NSScreen? {
        NSScreen.screens.first
    }

    var card: LyricsCard {
        float.card
    }

    init() {
        float.pointer = { [weak self] in self?.point ?? Self.away }
        float.buttons = { [weak self] in self?.buttons ?? 0 }
        float.now = { [weak self] in self?.clock ?? .now }
        float.reducesMotion = { true }
        float.card.reducesMotion = { true }
        float.desktop.reducesMotion = { true }
        float.onControl = { [weak self] control in self?.controls.append(control) }
        float.onMove = { [weak self] corner, screen in self?.moves.append((corner, screen)) }
        float.onDismiss = { [weak self] in self?.dismissals += 1 }
    }

    static func song(
        _ status: WidgetGrid.LyricsStatus, current: Int?, playing: Bool
    ) -> WidgetGrid.Verse {
        WidgetGrid.Verse(
            title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: playing,
            status: status, lines: lines, current: current, progress: progress,
            remaining: remaining)
    }

    func show(_ place: LyricsPlace) {
        guard let screen else { return }
        float.show(verse, place: place, look: look, on: screen, hidesInSharing: hidesInSharing)
        float.panel.contentView?.layoutSubtreeIfNeeded()
    }

    func wait(_ milliseconds: Int) {
        clock += .milliseconds(milliseconds)
        float.tick()
    }

    func hover(_ point: NSPoint) {
        self.point = point
        float.tick()
        float.panel.contentView?.layoutSubtreeIfNeeded()
    }

    func centre(of view: NSView) -> NSPoint {
        let rect = float.panel.convertToScreen(view.convert(view.bounds, to: nil))
        return NSPoint(x: rect.midX, y: rect.midY)
    }
}
