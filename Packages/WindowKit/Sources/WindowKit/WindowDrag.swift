public import CoreGraphics

public struct WindowDrag: Sendable {
    public enum Mode: Sendable {
        case move
        case resize
    }

    static let minimumSide: CGFloat = 80

    public let mode: Mode
    private let start: CGRect
    private let anchor: CGPoint
    private let movesMaxX: Bool
    private let movesMaxY: Bool

    public init(_ mode: Mode, window: CGRect, pointer: CGPoint) {
        self.mode = mode
        start = window
        anchor = pointer
        movesMaxX = pointer.x >= window.midX
        movesMaxY = pointer.y >= window.midY
    }

    private static func edges(
        min: CGFloat, max: CGFloat, by delta: CGFloat, movingMax: Bool
    ) -> (CGFloat, CGFloat) {
        let floor = Swift.min(minimumSide, max - min)
        return movingMax
            ? (min, Swift.max(max + delta, min + floor))
            : (Swift.min(min + delta, max - floor), max)
    }

    public func frame(pointer: CGPoint) -> CGRect {
        let shift = CGSize(width: pointer.x - anchor.x, height: pointer.y - anchor.y)
        guard mode == .resize else { return start.offsetBy(dx: shift.width, dy: shift.height) }
        let (minX, maxX) = Self.edges(
            min: start.minX, max: start.maxX, by: shift.width, movingMax: movesMaxX)
        let (minY, maxY) = Self.edges(
            min: start.minY, max: start.maxY, by: shift.height, movingMax: movesMaxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
