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
        let blockers: [HalfSnap.Blocker]
    }

    private let logger: Logger
    private let panel: OverlayPanel
    private let ring = RadialRing()
    private let preview: SnapPreview
    private let loadSettings: @MainActor () -> RadialSettings
    private let loadGap: @MainActor () -> CGFloat
    private var settings = RadialSettings()
    private var gap: CGFloat = 0
    private var resolver: RadialResolver?
    private var focus: Focus?
    private var lookup: Task<Void, Never>?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.move(to: location)
    }

    init(
        logger: Logger, panel: OverlayPanel, preview: SnapPreview,
        settings: @escaping @MainActor () -> RadialSettings,
        gap: @escaping @MainActor () -> CGFloat
    ) {
        self.logger = logger
        self.panel = panel
        self.preview = preview
        loadSettings = settings
        loadGap = gap
        panel.contentView = ring
    }

    @AccessibilityActor
    private static func focused() -> (frame: CGRect, blockers: [HalfSnap.Blocker])? {
        guard let window = try? FocusedWindow.frontmost(), let frame = try? window.quartzFrame()
        else { return nil }
        return (frame, HalfSnap.shared.blockers(besides: window))
    }

    @AccessibilityActor
    private static func place(
        _ action: RadialSettings.Action, gap: CGFloat, across screens: [ScreenGeometry.Screen]
    ) async throws(FocusedWindow.Failure) {
        if action == .fullScreen {
            try FocusedWindow.frontmost().enterFullScreen()
        } else if let layout = action.layout {
            try await WindowPlacement.layout(layout).apply(gap: gap, across: screens)
        }
    }

    func handle(_ event: ModifierTrigger.Event) {
        switch event {
        case .pressed:
            guard !(NSApp.keyWindow?.firstResponder is TriggerButton) else { return }
            resolver = nil
            settings = loadSettings()
            gap = loadGap()
            pointer.start()
            if pointer.isTracking {
                logger.debug("Pointer tracking started")
                if settings.showsPreview {
                    lookup = Task { [weak self] in
                        let found = await Self.focused()
                        guard !Task.isCancelled, let found else { return }
                        self?.begin(quartzFrame: found.frame, blockers: found.blockers)
                    }
                }
            }

        case .released:
            release()

        case .cancelled:
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

    private func release() {
        guard pointer.isTracking else { return }
        let action = resolver.map { settings.action(in: $0.zone) } ?? .nothing
        stop()
        guard action != .nothing else { return }
        let screens = NSScreen.screens.map { screen in
            ScreenGeometry.Screen(frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
        logger.debug("Radial action: \(action.rawValue, privacy: .public)")
        Task { [logger, gap] in
            do throws(FocusedWindow.Failure) {
                try await Self.place(action, gap: gap, across: screens)
            } catch {
                logger.error(
                    "Radial action failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func begin(quartzFrame: CGRect, blockers: [HalfSnap.Blocker]) {
        let screens = NSScreen.screens
        guard let primary = screens.first?.frame,
            let index = ScreenGeometry.screenIndex(
                showing: quartzFrame, in: screens.map(\.frame))
        else { return }
        let window = ScreenGeometry.appKitRect(fromQuartz: quartzFrame, primary: primary)
        let screen = screens[index]
        focus = Focus(
            window: window,
            screen: ScreenGeometry.Screen(frame: screen.frame, visibleFrame: screen.visibleFrame),
            blockers: blockers.map { blocker in
                HalfSnap.Blocker(
                    side: blocker.side,
                    frame: ScreenGeometry.appKitRect(fromQuartz: blocker.frame, primary: primary))
            })
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
        let action = settings.action(in: zone)
        var frame = action.previewFrame(of: focus.window, on: focus.screen, gap: gap)
        if let half = frame, let side = action.half {
            frame = HalfSnap.target(half, on: side, beside: focus.blockers, gap: gap)
        }
        preview.show(frame)
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
