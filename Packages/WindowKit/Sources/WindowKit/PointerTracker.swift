public import AppKit

@MainActor
public final class PointerTracker: NSObject {
    private let onMove: @MainActor (CGPoint) -> Void
    private var link: CADisplayLink?

    public var isTracking: Bool { link != nil }

    public init(onMove: @escaping @MainActor (CGPoint) -> Void) {
        self.onMove = onMove
    }

    public func start() {
        guard link == nil else { return }
        let location = NSEvent.mouseLocation
        guard
            let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
                ?? NSScreen.main
        else { return }
        let started = screen.displayLink(target: self, selector: #selector(step))
        started.add(to: .main, forMode: .common)
        link = started
        onMove(location)
    }

    public func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_: CADisplayLink) {
        onMove(NSEvent.mouseLocation)
    }
}
