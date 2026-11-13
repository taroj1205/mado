public import AppCore
import AppKit
import TouchPosition

public struct TrackpadSwipe {
    struct Touch {
        let id: AnyHashable
        let position: CGPoint
        let phase: NSTouch.Phase
    }

    static let openDistance: CGFloat = 0.015
    static let stepDistance: CGFloat = 0.03
    static let fingersToKeepSwiping = 2

    let fingers: Int
    private var starts: [AnyHashable: CGPoint] = [:]
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
            let all = NSEvent(cgEvent: event)?.allTouches().filter { $0.type == .indirect } ?? []
            guard !all.isEmpty else { return }
            let touches = all.compactMap { touch -> Touch? in
                guard NSTouch.Phase.touching.contains(touch.phase), !touch.isResting,
                    let id = touch.identity as? NSObject
                else { return nil }
                return Touch(id: id, position: MadoTouchPosition(touch), phase: touch.phase)
            }
            guard !touches.contains(where: { $0.position.x.isNaN || $0.position.y.isNaN }) else {
                return
            }
            swipe.handle(touches, emit: onEvent)
        }
    }

    private static func average(_ points: [CGPoint]) -> CGPoint {
        let count = CGFloat(points.count)
        return CGPoint(
            x: points.map(\.x).reduce(0, +) / count, y: points.map(\.y).reduce(0, +) / count)
    }

    mutating func handle(_ touches: [Touch], emit: (SwitcherKeys.Event) -> Void) {
        guard touches.count >= (isSwiping ? Self.fingersToKeepSwiping : fingers) else {
            if isSwiping { emit(.chosen) }
            self = Self(fingers: fingers)
            return
        }
        let moving = touches.filter { $0.phase == .began || $0.phase == .moved }
        if moving.count > fingers {
            if isSwiping { emit(.cancelled) }
            isSwiping = false
            isBlocked = true
        }
        guard !isBlocked else { return }
        let down = Set(touches.map(\.id))
        starts = starts.filter { down.contains($0.key) }
        guard !touches.contains(where: { $0.phase == .began || starts[$0.id] == nil }) else {
            rebase(touches)
            return
        }
        follow(moving, touches, emit: emit)
    }

    private mutating func follow(
        _ moving: [Touch], _ touches: [Touch], emit: (SwitcherKeys.Event) -> Void
    ) {
        let travel = moving.compactMap { touch in
            starts[touch.id].map { CGPoint(x: touch.position.x - $0.x, y: touch.position.y - $0.y) }
        }
        if isSwiping {
            guard travel.count >= Self.fingersToKeepSwiping else { return }
            step(Self.average(travel), touches, emit: emit)
        } else {
            guard travel.count == fingers else { return }
            open(travel, touches, emit: emit)
        }
    }

    private mutating func rebase(_ touches: [Touch]) {
        starts = Dictionary(touches.map { ($0.id, $0.position) }) { $1 }
    }

    private mutating func open(
        _ travel: [CGPoint], _ touches: [Touch], emit: (SwitcherKeys.Event) -> Void
    ) {
        let average = Self.average(travel)
        guard max(abs(average.x), abs(average.y)) >= Self.openDistance else { return }
        guard abs(average.x) > abs(average.y) else {
            isBlocked = true
            return
        }
        let backward = average.x < 0
        guard travel.allSatisfy({ ($0.x < 0) == backward && abs($0.x) >= Self.openDistance })
        else { return }
        emit(.stepped(backward: backward))
        isSwiping = true
        rebase(touches)
    }

    private mutating func step(
        _ travel: CGPoint, _ touches: [Touch], emit: (SwitcherKeys.Event) -> Void
    ) {
        let horizontal = abs(travel.x) > abs(travel.y)
        let distance = horizontal ? travel.x : travel.y
        let steps = Int(abs(distance) / Self.stepDistance)
        guard steps > 0 else { return }
        for _ in 0..<steps {
            emit(horizontal ? .stepped(backward: distance < 0) : .steppedRow(upward: distance > 0))
        }
        let moved = CGFloat(steps) * Self.stepDistance * (distance < 0 ? -1 : 1)
        for touch in touches {
            guard let start = starts[touch.id] else { continue }
            starts[touch.id] =
                horizontal
                ? CGPoint(x: start.x + moved, y: touch.position.y)
                : CGPoint(x: touch.position.x, y: start.y + moved)
        }
    }
}
