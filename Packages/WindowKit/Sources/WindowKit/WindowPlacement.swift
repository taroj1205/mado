public import CoreGraphics

public enum WindowPlacement: Hashable, Sendable {
    case display(step: Int)
    case layout(LayoutEngine.Action)
    case restore

    private static let sides: [LayoutEngine.Action: HalfSnap.Side] = [
        .leftHalf: .left, .rightHalf: .right,
    ]

    @AccessibilityActor private static let halves = HalfSnap()

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

    @AccessibilityActor
    public func apply(
        gap: CGFloat, across screens: [ScreenGeometry.Screen]
    ) async throws(FocusedWindow.Failure) {
        let window = try FocusedWindow.frontmost()
        let mover = WindowMover.shared
        switch self {
        case .restore:
            _ = try await mover.restore(window)

        case .display(let step):
            _ = try await mover.move(window, displays: step, across: screens)

        case .layout(let action):
            let current = try window.quartzFrame()
            guard let target = Self.quartzFrame(for: action, of: current, across: screens, gap: gap)
            else { return }
            if let side = Self.sides[action] {
                _ = try Self.halves.place(window, on: side, at: target, gap: gap)
            } else {
                _ = try mover.move(window, to: target)
            }
        }
    }
}
