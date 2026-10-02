public import CoreGraphics

public enum LayoutEngine {
    public enum Action: CaseIterable, Sendable {
        case almostMaximize, bottomHalf, bottomLeftQuarter, bottomRightQuarter, bottomThird
        case bottomTwoThirds, centre, centreThird, leftHalf, leftThird, leftTwoThirds, maximize
        case rightHalf, rightThird, rightTwoThirds, topHalf, topLeftQuarter, topRightQuarter
        case topThird, topTwoThirds
    }

    private static let half: CGFloat = 0.5
    private static let almostMaximized: CGFloat = 0.9
    private static let grid: CGFloat = 6
    private static let halfSpan: CGFloat = 3
    private static let thirdSpan: CGFloat = 2
    private static let twoThirdSpan: CGFloat = 4
    private static let cells: [Action: CGRect] = [
        .leftHalf: CGRect(x: 0, y: 0, width: halfSpan, height: grid),
        .rightHalf: CGRect(x: halfSpan, y: 0, width: halfSpan, height: grid),
        .topHalf: CGRect(x: 0, y: halfSpan, width: grid, height: halfSpan),
        .bottomHalf: CGRect(x: 0, y: 0, width: grid, height: halfSpan),
        .topLeftQuarter: CGRect(x: 0, y: halfSpan, width: halfSpan, height: halfSpan),
        .topRightQuarter: CGRect(x: halfSpan, y: halfSpan, width: halfSpan, height: halfSpan),
        .bottomLeftQuarter: CGRect(x: 0, y: 0, width: halfSpan, height: halfSpan),
        .bottomRightQuarter: CGRect(x: halfSpan, y: 0, width: halfSpan, height: halfSpan),
        .leftThird: CGRect(x: 0, y: 0, width: thirdSpan, height: grid),
        .centreThird: CGRect(x: thirdSpan, y: 0, width: thirdSpan, height: grid),
        .rightThird: CGRect(x: twoThirdSpan, y: 0, width: thirdSpan, height: grid),
        .leftTwoThirds: CGRect(x: 0, y: 0, width: twoThirdSpan, height: grid),
        .rightTwoThirds: CGRect(x: thirdSpan, y: 0, width: twoThirdSpan, height: grid),
        .topThird: CGRect(x: 0, y: twoThirdSpan, width: grid, height: thirdSpan),
        .bottomThird: CGRect(x: 0, y: 0, width: grid, height: thirdSpan),
        .topTwoThirds: CGRect(x: 0, y: thirdSpan, width: grid, height: twoThirdSpan),
        .bottomTwoThirds: CGRect(x: 0, y: 0, width: grid, height: twoThirdSpan),
        .maximize: CGRect(x: 0, y: 0, width: grid, height: grid),
    ]

    public static func frame(
        for action: Action, in visibleFrame: CGRect, gap requested: CGFloat, windowSize: CGSize
    ) -> CGRect {
        let largestGap =
            min(visibleFrame.width, visibleFrame.height) * thirdSpan / (grid + thirdSpan)
        let gap = requested >= 0 && requested < largestGap ? requested : 0
        if let cell = cells[action] {
            let inset = gap * half
            let area = visibleFrame.insetBy(dx: inset, dy: inset)
            return CGRect(
                x: area.minX + area.width * cell.minX / grid,
                y: area.minY + area.height * cell.minY / grid,
                width: area.width * cell.width / grid,
                height: area.height * cell.height / grid
            ).insetBy(dx: inset, dy: inset)
        }
        let size =
            action == .almostMaximize
            ? CGSize(
                width: visibleFrame.width * almostMaximized,
                height: visibleFrame.height * almostMaximized)
            : windowSize
        return ScreenGeometry.centeredFrame(
            of: size, in: visibleFrame.insetBy(dx: gap, dy: gap))
    }
}
