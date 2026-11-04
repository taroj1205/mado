public import AppCore
import AppKit
import TouchPosition

public struct TrackpadSwipe {
    static let openDistance: CGFloat = 20
    static let stepDistance: CGFloat = 14
    static let fingersToKeepSwiping = 2

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
            let points = touches.filter { touch in
                NSTouch.Phase.touching.contains(touch.phase) && !touch.isResting
            }
            .map(MadoTouchPosition)
            guard !points.contains(where: { $0.x.isNaN || $0.y.isNaN }) else { return }
            swipe.handle(points, emit: onEvent)
        }
    }

    mutating func handle(_ points: [CGPoint], emit: (SwitcherKeys.Event) -> Void) {
        guard points.count >= (isSwiping ? Self.fingersToKeepSwiping : fingers) else {
            if isSwiping { emit(.chosen) }
            self = Self(fingers: fingers)
            return
        }
        if points.count > fingers {
            if isSwiping { emit(.cancelled) }
            isSwiping = false
            isBlocked = true
        }
        guard !isBlocked else { return }
        guard points.count == fingers else {
            anchor = nil
            return
        }
        let count = CGFloat(points.count)
        move(
            to: CGPoint(
                x: points.map(\.x).reduce(0, +) / count, y: points.map(\.y).reduce(0, +) / count),
            emit: emit)
    }

    private mutating func move(to center: CGPoint, emit: (SwitcherKeys.Event) -> Void) {
        guard let anchor else {
            anchor = center
            return
        }
        let travel = CGPoint(x: center.x - anchor.x, y: center.y - anchor.y)
        let horizontal = abs(travel.x) > abs(travel.y)
        guard isSwiping else {
            guard max(abs(travel.x), abs(travel.y)) >= Self.openDistance else { return }
            if horizontal {
                emit(.stepped(backward: travel.x < 0))
                isSwiping = true
                self.anchor = center
            } else {
                isBlocked = true
            }
            return
        }
        let distance = horizontal ? travel.x : travel.y
        let steps = Int(abs(distance) / Self.stepDistance)
        guard steps > 0 else { return }
        let moved = CGFloat(steps) * Self.stepDistance * (distance < 0 ? -1 : 1)
        if horizontal {
            for _ in 0..<steps { emit(.stepped(backward: distance < 0)) }
            self.anchor = CGPoint(x: anchor.x + moved, y: center.y)
        } else {
            for _ in 0..<steps { emit(.steppedRow(upward: distance > 0)) }
            self.anchor = CGPoint(x: center.x, y: anchor.y + moved)
        }
    }
}
