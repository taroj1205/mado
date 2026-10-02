import AppCore
import AppKit
import GlassUI
import InputKit
import os
import WindowKit

@MainActor
final class WindowGesture {
    private struct Drag {
        let gesture: WindowDrag
        let held: Shortcut.Modifiers
        let start: CGRect
        var shown: CGRect?
    }

    private let logger: Logger
    private let settings: @MainActor () -> GestureSettings
    private let overlay = GestureOverlay()
    private var drag: Drag?
    private var follower: WindowFollower?
    private var lookup: Task<Void, Never>?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.follow(location)
    }

    init(logger: Logger, settings: @escaping @MainActor () -> GestureSettings) {
        self.logger = logger
        self.settings = settings
    }

    @AccessibilityActor
    private static func window(
        _ target: GestureSettings.Target, at quartzPoint: CGPoint
    ) -> (window: FocusedWindow, frame: CGRect)? {
        let window =
            switch target {
            case .activeWindow: try? FocusedWindow.frontmost()
            case .underMouse: try? FocusedWindow.under(quartzPoint: quartzPoint)
            }
        guard let window, let frame = try? window.quartzFrame() else { return nil }
        return (window, frame)
    }

    @AccessibilityActor
    private static func apply(
        _ frame: CGRect, to window: FocusedWindow, from previous: CGRect
    ) -> FocusedWindow.Failure? {
        do {
            try window.setFrame(frame, changedFrom: previous)
            return nil
        } catch {
            return error
        }
    }

    func handle(_ event: ModifierTrigger.Event, mode: WindowDrag.Mode, held: Shortcut.Modifiers) {
        switch event {
        case .pressed:
            guard !(NSApp.keyWindow?.firstResponder is TriggerButton) else { return }
            begin(mode, held: held)

        case .released:
            stop()

        case .cancelled:
            if let drag {
                follower?.send(drag.start, throttled: false)
            }
            stop()

        case .clicked:
            break
        }
    }

    func stop() {
        lookup?.cancel()
        lookup = nil
        endDrag()
    }

    private func endDrag() {
        pointer.stop()
        drag = nil
        overlay.hide()
    }

    private func begin(_ mode: WindowDrag.Mode, held: Shortcut.Modifiers) {
        stop()
        guard let primary = NSScreen.screens.first?.frame else { return }
        let target = settings().target
        let point = ScreenGeometry.quartzRect(
            fromAppKit: CGRect(origin: NSEvent.mouseLocation, size: .zero), primary: primary
        ).origin
        let previous = follower
        lookup = Task { [weak self] in
            await previous?.finish()
            guard !Task.isCancelled, let found = await Self.window(target, at: point),
                !Task.isCancelled
            else { return }
            self?.start(mode, held: held, window: found.window, quartzFrame: found.frame)
        }
    }

    private func start(
        _ mode: WindowDrag.Mode, held: Shortcut.Modifiers, window: FocusedWindow,
        quartzFrame: CGRect
    ) {
        guard let primary = NSScreen.screens.first?.frame else { return }
        let frame = ScreenGeometry.appKitRect(fromQuartz: quartzFrame, primary: primary)
        follower = WindowFollower(from: quartzFrame) { [weak self] target, previous in
            guard let failure = await Self.apply(target, to: window, from: previous) else {
                return true
            }
            self?.logger.error(
                "Window gesture failed: \(String(describing: failure), privacy: .public)")
            self?.endDrag()
            return false
        }
        drag = Drag(
            gesture: WindowDrag(mode, window: frame, pointer: NSEvent.mouseLocation),
            held: held, start: quartzFrame)
        pointer.start()
        logger.debug("Window \(String(describing: mode), privacy: .public) started")
    }

    private func follow(_ location: CGPoint) {
        guard var drag, let primary = NSScreen.screens.first?.frame else { return }
        let frame = drag.gesture.frame(pointer: location)
        guard frame != drag.shown else { return }
        drag.shown = frame
        self.drag = drag
        let quartz = ScreenGeometry.quartzRect(fromAppKit: frame, primary: primary)
        overlay.show(frame, status: status(of: drag, quartzFrame: quartz))
        follower?.send(quartz, throttled: drag.gesture.mode == .resize)
    }

    private func status(of drag: Drag, quartzFrame: CGRect) -> GestureOverlay.Status {
        switch drag.gesture.mode {
        case .move:
            let frames = NSScreen.screens.map(\.frame)
            let index = ScreenGeometry.screenIndex(showing: quartzFrame, in: frames) ?? 0
            return .move(held: drag.held, display: index + 1, displays: frames.count)

        case .resize:
            return .resize(quartzFrame.size)
        }
    }
}
