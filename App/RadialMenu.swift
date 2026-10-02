import AppKit
import GlassUI
import InputKit
import os
import WindowKit

@MainActor
final class RadialMenu {
    private let logger: Logger
    private let panel: OverlayPanel
    private let ring = RadialRing()
    private var resolver: RadialResolver?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.move(to: location)
    }

    init(logger: Logger, panel: OverlayPanel) {
        self.logger = logger
        self.panel = panel
        panel.contentView = ring
    }

    func handle(_ event: ModifierTrigger.Event) {
        switch event {
        case .pressed:
            resolver = nil
            pointer.start()
            if pointer.isTracking {
                logger.debug("Pointer tracking started")
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
        logger.debug("Pointer tracking stopped")
        ring.disappear { [panel] in panel.orderOut(nil) }
    }

    private func move(to location: CGPoint) {
        if resolver == nil {
            panel.setFrame(RadialRing.frame(centredOn: location), display: false)
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
        }
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
