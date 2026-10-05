public import AppKit

@MainActor
public final class LyricsFloat {
    struct Drag {
        let grab: NSSize
        let corner: LyricsCorner
        let screen: NSScreen?
        var moved = false
    }

    static let radius: CGFloat = 22
    static let fadeSeconds = 0.25
    static let hoverMilliseconds = 250
    static let pollMilliseconds = 70
    private static let desktopLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

    public var onControl: ((LyricsControl) -> Void)?
    public var onMove: ((LyricsCorner, NSScreen) -> Void)?
    public var onDismiss: (() -> Void)?
    public var pointer: @MainActor () -> NSPoint = { NSEvent.mouseLocation }
    var clicks = { LyricsFloat.systemClicks() }
    var now = { ContinuousClock.now }
    var screens = { NSScreen.screens }
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))
    let card = LyricsCard()
    let desktopPanel = OverlayPanel()
    let desktop = LyricsDesktop()
    var slots: [LyricsCorner: OverlayPanel] = [:]
    var place: LyricsPlace?
    var look = LyricsLook.line
    var screen: NSScreen?
    var grown = false
    var hoverSince: ContinuousClock.Instant?
    var drag: Drag?
    var target: NSRect?
    var seenClicks = 0
    private var poll: Task<Void, Never>?
    public private(set) var isShown = false

    public var frame: NSRect {
        window.frame
    }

    var window: NSWindow {
        place == .desktop ? desktopPanel : panel
    }

    var shownLook: LyricsLook {
        guard look == .line else { return look }
        if grown { return .card }
        if case .menuBar = place { return .card }
        return .line
    }

    public init() {
        panel.animationBehavior = .none
        panel.glass.contentView = card
        let border = GlassBorder(radius: Self.radius)
        border.frame = panel.glass.container.bounds
        border.autoresizingMask = [.width, .height]
        panel.glass.container.addSubview(border)
        card.onControl = { [weak self] control in self?.onControl?(control) }
        card.onDrag = { [weak self] phase in self?.drag(phase) }
        desktopPanel.contentView = desktop
        desktopPanel.level = Self.desktopLevel
        desktopPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        desktopPanel.animationBehavior = .none
    }

    public func show(
        _ verse: WidgetGrid.Verse, place: LyricsPlace, look: LyricsLook, on screen: NSScreen,
        hidesInSharing: Bool
    ) {
        if place != self.place || look != self.look {
            grown = false
            hoverSince = nil
        }
        if (place == .desktop) != (self.place == .desktop) {
            window.orderOut(nil)
        }
        if !isShown || place != self.place {
            seenClicks = clicks()
        }
        self.place = place
        self.look = look
        self.screen = screen
        window.sharingType = hidesInSharing ? .none : .readOnly
        if place == .desktop {
            desktop.show(verse)
        } else {
            card.show(verse)
        }
        settle(animated: false)
        if !isShown || !window.isVisible {
            fadeIn()
        }
        if place == .desktop { stopWatching() } else { watch() }
    }

    public func hide(animated: Bool) {
        isShown = false
        stopWatching()
        hideSlots()
        drag = nil
        grown = false
        hoverSince = nil
        target = nil
        guard animated else {
            closeWindows()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeSeconds
            panel.animator().alphaValue = 0
            desktopPanel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, !isShown else { return }
                closeWindows()
            }
        }
    }

    func settle(animated: Bool) {
        guard let place, let screen, drag == nil else { return }
        let size = place == .desktop ? desktop.fittingSize : shownLook.size
        let next = LyricsGeometry.frame(for: place, size: size, in: screen.visibleFrame)
        guard next != target else { return }
        target = next
        let moves = animated && !reducesMotion()
        card.setLook(shownLook, animated: moves)
        guard moves else {
            window.setFrame(next, display: true)
            return
        }
        let moving = window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = LyricsCard.growSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            moving.animator().setFrame(next, display: true)
        }
    }

    private func fadeIn() {
        isShown = true
        let shown = window
        shown.alphaValue = 0
        shown.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeSeconds
            shown.animator().alphaValue = 1
        }
    }

    private func closeWindows() {
        panel.orderOut(nil)
        desktopPanel.orderOut(nil)
    }

    private func watch() {
        guard poll == nil else { return }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                tick()
                try? await Task.sleep(for: .milliseconds(Self.pollMilliseconds))
            }
        }
    }

    private func stopWatching() {
        poll?.cancel()
        poll = nil
        panel.ignoresMouseEvents = true
    }
}
