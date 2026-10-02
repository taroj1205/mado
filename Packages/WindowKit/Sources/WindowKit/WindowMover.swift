public import ApplicationServices

@AccessibilityActor
public final class WindowMover {
    public typealias Failure = FocusedWindow.Failure

    struct Placement {
        let restore: CGRect
        let placed: CGRect
    }

    public static let shared = WindowMover()

    private static let settleMilliseconds = 50

    private var placements: [AXUIElement: Placement] = [:]

    nonisolated static func restoreFrame(keeping placement: Placement?, current: CGRect) -> CGRect {
        guard let placement, placement.placed == current else { return current }
        return placement.restore
    }

    public func move(_ window: FocusedWindow, to quartzFrame: CGRect) throws(Failure) -> CGRect {
        try place(window, from: window.quartzFrame(), to: quartzFrame)
    }

    public func move(
        _ window: FocusedWindow, displays step: Int, across screens: [ScreenGeometry.Screen]
    ) async throws(Failure) -> CGRect? {
        let current = try window.quartzFrame()
        let target = ScreenGeometry.quartzFrame(current, movedBy: step, across: screens)
        guard let target else { return nil }
        let placed = try place(window, from: current, to: target)
        guard try await shouldSetAgain(window, placed: placed, target: target) else {
            return placed
        }
        return try place(window, from: placed, to: target)
    }

    public func restore(_ window: FocusedWindow) async throws(Failure) -> CGRect? {
        guard let placement = placements[window.element] else { return nil }
        let restored = try window.setFrame(placement.restore)
        placements[window.element] = nil
        guard try await shouldSetAgain(window, placed: restored, target: placement.restore) else {
            return restored
        }
        return try window.setFrame(placement.restore)
    }

    private func shouldSetAgain(
        _ window: FocusedWindow, placed: CGRect, target: CGRect
    ) async throws(Failure) -> Bool {
        guard placed.size != target.size else { return false }
        try? await Task.sleep(for: .milliseconds(Self.settleMilliseconds))
        return try window.quartzFrame() == placed
    }

    private func place(
        _ window: FocusedWindow, from current: CGRect, to target: CGRect
    ) throws(Failure) -> CGRect {
        let restore = Self.restoreFrame(keeping: placements[window.element], current: current)
        let placed = try window.setFrame(target)
        placements[window.element] = Placement(restore: restore, placed: placed)
        return placed
    }
}
