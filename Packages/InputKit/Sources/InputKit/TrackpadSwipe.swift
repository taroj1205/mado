public import AppCore
import AppKit
import TouchPosition

public struct TrackpadSwipe {
    static let stepDistance: CGFloat = 0.03

    let fingers: Int
    private var anchor: CGPoint?
    private var isSwiping = false
    private var isBlocked = false

    init(fingers: Int) {
        self.fingers = fingers
    }

    @MainActor
    public static func install(
        fingers: Int, name: String, context: ModuleContext,
        onEvent: @escaping @MainActor (SwitcherKeys.Event) -> Void
    ) throws(ModuleError) {
        var swipe = Self(fingers: fingers)
        try context.observeGestures(name) { event in
            let touches =
                NSEvent(cgEvent: event)?.allTouches().filter { $0.type == .indirect } ?? []
            guard !touches.isEmpty else { return }
            let points = touches.filter { NSTouch.Phase.touching.contains($0.phase) }
                .map(MadoTouchPosition)
            guard !points.contains(where: { $0.x.isNaN || $0.y.isNaN }) else { return }
            swipe.handle(points, emit: onEvent)
        }
    }

    mutating func handle(_ points: [CGPoint], emit: (SwitcherKeys.Event) -> Void) {
        guard points.count >= fingers else {
            if isSwiping { emit(.chosen) }
            self = Self(fingers: fingers)
            return
        }
        isBlocked = isBlocked || points.count > fingers
        guard !isBlocked else { return }
        let count = CGFloat(points.count)
        let center = CGPoint(
            x: points.map(\.x).reduce(0, +) / count, y: points.map(\.y).reduce(0, +) / count)
        guard let anchor else {
            anchor = center
            return
        }
        let travel = CGPoint(x: center.x - anchor.x, y: center.y - anchor.y)
        guard max(abs(travel.x), abs(travel.y)) >= Self.stepDistance else { return }
        self.anchor = center
        if abs(travel.x) > abs(travel.y) {
            emit(.stepped(backward: travel.x < 0))
            isSwiping = true
        } else if isSwiping {
            emit(.steppedRow(upward: travel.y > 0))
        } else {
            isBlocked = true
        }
    }
}
