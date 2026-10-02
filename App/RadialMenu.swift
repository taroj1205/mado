import AppKit
import InputKit
import os
import WindowKit

@MainActor
final class RadialMenu {
    private let logger: Logger
    private var resolver: RadialResolver?
    private lazy var pointer = PointerTracker { [weak self] location in
        self?.move(to: location)
    }

    init(logger: Logger) {
        self.logger = logger
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
    }

    private func move(to location: CGPoint) {
        var next = resolver ?? RadialResolver(origin: location)
        let zone = next.zone
        next.update(pointer: location)
        resolver = next
        if next.zone != zone {
            logger.debug("Radial zone: \(String(describing: next.zone), privacy: .public)")
        }
    }
}
