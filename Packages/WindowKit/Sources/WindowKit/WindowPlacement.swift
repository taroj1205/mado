public import ApplicationServices

public enum WindowPlacement: Hashable, Sendable {
    case display(step: Int)
    case layout(LayoutEngine.Action)
    case restore

    struct Placed {
        let window: AXUIElement
        let frame: CGRect
        let requested: LayoutEngine.Action
        let applied: LayoutEngine.Action
    }

    static let sides: [LayoutEngine.Action: HalfSnap.Side] = [
        .leftHalf: .left, .rightHalf: .right,
    ]
    static let sizeCycles: [[LayoutEngine.Action]] = [
        [.leftHalf, .leftThird, .leftTwoThirds],
        [.rightHalf, .rightThird, .rightTwoThirds],
        [.topHalf, .topThird, .topTwoThirds],
        [.bottomHalf, .bottomThird, .bottomTwoThirds],
    ]

    @AccessibilityActor private static var lastPlaced: Placed?

    nonisolated static func quartzFrame(
        for action: LayoutEngine.Action, of window: CGRect, across screens: [ScreenGeometry.Screen],
        gap: CGFloat
    ) -> CGRect? {
        guard let primary = screens.first?.frame,
            let index = ScreenGeometry.screenIndex(showing: window, in: screens.map(\.frame))
        else { return nil }
        let frame = LayoutEngine.frame(
            for: action, in: screens[index].visibleFrame, gap: gap, windowSize: window.size)
        return ScreenGeometry.quartzRect(fromAppKit: frame, primary: primary)
    }

    nonisolated static func action(
        for requested: LayoutEngine.Action, of window: AXUIElement, at frame: CGRect,
        after last: Placed?
    ) -> LayoutEngine.Action {
        guard let last, last.requested == requested, last.window == window, last.frame == frame,
            let sizes = sizeCycles.first(where: { $0.first == requested }),
            let index = sizes.firstIndex(of: last.applied)
        else { return requested }
        return sizes[(index + 1) % sizes.count]
    }

    @AccessibilityActor
    public func apply(
        gap: CGFloat, cyclesSizes: Bool, across screens: [ScreenGeometry.Screen]
    ) async throws(FocusedWindow.Failure) {
        let window = try FocusedWindow.frontmost()
        let mover = WindowMover.shared
        switch self {
        case .restore:
            _ = try await mover.restore(window)

        case .display(let step):
            _ = try await mover.move(window, displays: step, across: screens)

        case .layout(let requested):
            let current = try window.quartzFrame()
            let action = Self.action(
                for: requested, of: window.element, at: current,
                after: cyclesSizes ? Self.lastPlaced : nil)
            guard let target = Self.quartzFrame(for: action, of: current, across: screens, gap: gap)
            else { return }
            let placed =
                if let side = Self.sides[action] {
                    try HalfSnap.shared.place(window, on: side, at: target, gap: gap)
                } else {
                    try mover.move(window, to: target)
                }
            Self.lastPlaced = Placed(
                window: window.element, frame: placed, requested: requested, applied: action)
        }
    }
}
