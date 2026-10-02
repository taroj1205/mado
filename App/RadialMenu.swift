import AppKit
import GlassUI
import InputKit
import os
import WindowKit

@MainActor
final class RadialMenu {
    private struct Focus {
        let window: CGRect
        let screen: ScreenGeometry.Screen
    }

    private let logger: Logger
    private let panel: OverlayPanel
    private let ring = RadialRing()
    private let preview: SnapPreview
    private let loadSettings: @MainActor () -> RadialSettings
    private var settings = RadialSettings()
    private var resolver: RadialResolver?
    private var focus: Focus?
    private var lookup: Task<Void, Never>?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.move(to: location)
    }

    init(
        logger: Logger, panel: OverlayPanel, preview: SnapPreview,
        settings: @escaping @MainActor () -> RadialSettings
    ) {
        self.logger = logger
        self.panel = panel
        self.preview = preview
        loadSettings = settings
        panel.contentView = ring
    }

    @AccessibilityActor
    private static func focusedFrame() -> CGRect? {
        try? FocusedWindow.frontmost().quartzFrame()
    }

    func handle(_ event: ModifierTrigger.Event) {
        switch event {
        case .pressed:
            guard !(NSApp.keyWindow?.firstResponder is TriggerButton) else { return }
            resolver = nil
            settings = loadSettings()
            pointer.start()
            if pointer.isTracking {
                logger.debug("Pointer tracking started")
                if settings.showsPreview {
                    lookup = Task { [weak self] in
                        let frame = await Self.focusedFrame()
                        guard !Task.isCancelled, let frame else { return }
                        self?.begin(quartzFrame: frame)
                    }
                }
            }

        case .released, .cancelled:
            stop()

        case .clicked:
            break
        }
    }

    func stop() {
        guard pointer.isTracking else { return }
        pointer.stop()
        lookup?.cancel()
        lookup = nil
        focus = nil
        preview.end()
        logger.debug("Pointer tracking stopped")
        ring.disappear { [panel] in panel.orderOut(nil) }
    }

    private func begin(quartzFrame: CGRect) {
        let screens = NSScreen.screens
        guard let primary = screens.first?.frame,
            let index = ScreenGeometry.screenIndex(
                showing: quartzFrame, in: screens.map(\.frame))
        else { return }
        let window = ScreenGeometry.appKitRect(fromQuartz: quartzFrame, primary: primary)
        let screen = screens[index]
        focus = Focus(
            window: window,
            screen: ScreenGeometry.Screen(frame: screen.frame, visibleFrame: screen.visibleFrame))
        preview.begin(from: window, on: screen)
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
        showPreview()
    }

    private func move(to location: CGPoint) {
        if resolver == nil {
            panel.setFrame(RadialRing.frame(centredOn: ringCentre(for: location)), display: false)
            panel.orderFrontRegardless()
            ring.appear()
        }
        var next = resolver ?? RadialResolver(origin: location)
        let zone = next.zone
        next.update(pointer: location)
        resolver = next
        if next.zone != zone {
            logger.debug("Radial zone: \(String(describing: next.zone), privacy: .public)")
            ring.select(RadialRing.Highlight(next.zone))
            if settings.haptics {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment, performanceTime: .default)
            }
            showPreview()
        }
    }

    private func ringCentre(for location: CGPoint) -> CGPoint {
        guard settings.opensAt == .screenCentre,
            let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
        else { return location }
        return CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY)
    }

    private func showPreview() {
        guard let focus, let zone = resolver?.zone else { return }
        preview.show(
            settings.action(in: zone).previewFrame(of: focus.window, on: focus.screen, gap: 0))
    }
}

extension RadialRing.Highlight {
    init(_ zone: RadialResolver.Zone) {
        switch zone {
        case .cancel: self = .cancel
        case .ring: self = .ring
        case .direction(let direction): self = .direction(degrees: direction.degrees)
        }
    }
}
