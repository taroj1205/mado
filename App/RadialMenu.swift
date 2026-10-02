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
    private let preview: SnapPreview
    private let settings = RadialSettings()
    private var resolver: RadialResolver?
    private var focus: Focus?
    private var lookup: Task<Void, Never>?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.move(to: location)
    }

    init(logger: Logger, preview: SnapPreview) {
        self.logger = logger
        self.preview = preview
    }

    @AccessibilityActor
    private static func focusedFrame() -> CGRect? {
        try? FocusedWindow.frontmost().quartzFrame()
    }

    func handle(_ event: ModifierTrigger.Event) {
        switch event {
        case .pressed:
            resolver = nil
            pointer.start()
            if pointer.isTracking {
                logger.debug("Pointer tracking started")
                lookup = Task { [weak self] in
                    let frame = await Self.focusedFrame()
                    guard !Task.isCancelled, let frame else { return }
                    self?.begin(quartzFrame: frame)
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
        showPreview()
    }

    private func move(to location: CGPoint) {
        var next = resolver ?? RadialResolver(origin: location)
        let zone = next.zone
        next.update(pointer: location)
        resolver = next
        if next.zone != zone {
            logger.debug("Radial zone: \(String(describing: next.zone), privacy: .public)")
            showPreview()
        }
    }

    private func showPreview() {
        guard let focus, let zone = resolver?.zone else { return }
        preview.show(
            settings.action(in: zone).previewFrame(of: focus.window, on: focus.screen, gap: 0))
    }
}
