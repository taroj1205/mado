public import CoreGraphics

@AccessibilityActor
public final class HalfSnap {
    public enum Side: Sendable {
        case left, right
    }

    public struct Blocker: Sendable {
        public let side: Side
        public let frame: CGRect

        public init(side: Side, frame: CGRect) {
            self.side = side
            self.frame = frame
        }
    }

    private struct Refusal {
        let side: Side
        let window: FocusedWindow
        let frame: CGRect
    }

    public static let shared = HalfSnap()

    private var refusals: [Refusal]

    public init() {
        refusals = []
    }

    nonisolated static func remaining(
        of frame: CGRect, beside other: CGRect, on side: Side, gap: CGFloat
    ) -> CGRect {
        guard frame.intersects(other) else { return frame }
        let minX = side == .right ? max(frame.minX, other.maxX + gap) : frame.minX
        let maxX = side == .left ? min(frame.maxX, other.minX - gap) : frame.maxX
        guard maxX > minX else { return frame }
        return CGRect(x: minX, y: frame.minY, width: maxX - minX, height: frame.height)
    }

    nonisolated public static func target(
        _ frame: CGRect, on side: Side, beside blockers: [Blocker], gap: CGFloat
    ) -> CGRect {
        blockers.filter { $0.side != side }.reduce(frame) { target, blocker in
            remaining(of: target, beside: blocker.frame, on: side, gap: gap)
        }
    }

    public func blockers(besides window: FocusedWindow) -> [Blocker] {
        refusals.removeAll { refusal in
            refusal.window.element == window.element
                || (try? refusal.window.quartzFrame()) != refusal.frame
        }
        return refusals.filter(\.window.isVisible).map { refusal in
            Blocker(side: refusal.side, frame: refusal.frame)
        }
    }

    public func place(
        _ window: FocusedWindow, on side: Side, at frame: CGRect, gap: CGFloat
    ) throws(FocusedWindow.Failure) -> CGRect {
        let target = Self.target(frame, on: side, beside: blockers(besides: window), gap: gap)
        let mover = WindowMover.shared
        var placed = try mover.move(window, to: target)
        if placed.width > target.width {
            if side == .right {
                placed = try mover.move(
                    window, to: placed.offsetBy(dx: target.maxX - placed.maxX, dy: 0))
            }
            refusals.append(Refusal(side: side, window: window, frame: placed))
        }
        return placed
    }
}
