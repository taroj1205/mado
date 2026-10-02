public import CoreGraphics

@AccessibilityActor
public final class HalfSnap {
    public enum Side: Sendable {
        case left, right
    }

    private struct Refusal {
        let side: Side
        let window: FocusedWindow
        let frame: CGRect
    }

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

    public func place(
        _ window: FocusedWindow, on side: Side, at frame: CGRect, gap: CGFloat
    ) throws(FocusedWindow.Failure) -> CGRect {
        refusals.removeAll { refusal in
            refusal.window.element == window.element
                || (try? refusal.window.quartzFrame()) != refusal.frame
        }
        let beside = refusals.filter { $0.side != side && $0.window.isVisible }
        let target = beside.reduce(frame) { target, refusal in
            Self.remaining(of: target, beside: refusal.frame, on: side, gap: gap)
        }
        var placed = try window.setFrame(target)
        if placed.width > target.width {
            if side == .right {
                placed = try window.setFrame(placed.offsetBy(dx: target.maxX - placed.maxX, dy: 0))
            }
            refusals.append(Refusal(side: side, window: window, frame: placed))
        }
        return placed
    }
}
