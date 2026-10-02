public import CoreGraphics

public enum LayoutEngine {
    public enum Action: CaseIterable, Sendable {
        case almostMaximize, bottomHalf, bottomLeftQuarter, bottomRightQuarter, centre
        case centreThird, leftHalf, leftThird, leftTwoThirds, maximize, rightHalf, rightThird
        case rightTwoThirds, topHalf, topLeftQuarter, topRightQuarter
    }

    private static let half: CGFloat = 0.5
    private static let almostMaximized: CGFloat = 0.9
    private static let columns: CGFloat = 6
    private static let rows: CGFloat = 2
    private static let halfColumns: CGFloat = 3
    private static let thirdColumns: CGFloat = 2
    private static let twoThirdColumns: CGFloat = 4
    private static let cells: [Action: CGRect] = [
        .leftHalf: CGRect(x: 0, y: 0, width: halfColumns, height: rows),
        .rightHalf: CGRect(x: halfColumns, y: 0, width: halfColumns, height: rows),
        .topHalf: CGRect(x: 0, y: 1, width: columns, height: 1),
        .bottomHalf: CGRect(x: 0, y: 0, width: columns, height: 1),
        .topLeftQuarter: CGRect(x: 0, y: 1, width: halfColumns, height: 1),
        .topRightQuarter: CGRect(x: halfColumns, y: 1, width: halfColumns, height: 1),
        .bottomLeftQuarter: CGRect(x: 0, y: 0, width: halfColumns, height: 1),
        .bottomRightQuarter: CGRect(x: halfColumns, y: 0, width: halfColumns, height: 1),
        .leftThird: CGRect(x: 0, y: 0, width: thirdColumns, height: rows),
        .centreThird: CGRect(x: thirdColumns, y: 0, width: thirdColumns, height: rows),
        .rightThird: CGRect(x: twoThirdColumns, y: 0, width: thirdColumns, height: rows),
        .leftTwoThirds: CGRect(x: 0, y: 0, width: twoThirdColumns, height: rows),
        .rightTwoThirds: CGRect(x: thirdColumns, y: 0, width: twoThirdColumns, height: rows),
        .maximize: CGRect(x: 0, y: 0, width: columns, height: rows),
    ]

    public static func frame(
        for action: Action, in visibleFrame: CGRect, gap: CGFloat, windowSize: CGSize
    ) -> CGRect {
        if let cell = cells[action] {
            let inset = gap * half
            let area = visibleFrame.insetBy(dx: inset, dy: inset)
            return CGRect(
                x: area.minX + area.width * cell.minX / columns,
                y: area.minY + area.height * cell.minY / rows,
                width: area.width * cell.width / columns,
                height: area.height * cell.height / rows
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
