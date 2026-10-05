import CoreGraphics

struct AreaSelection: Equatable {
    static let smallest: CGFloat = 4
    private static let badgeGap: CGFloat = 4
    private static let badgeInset: CGFloat = 3

    private let anchor: CGPoint
    private var point: CGPoint
    private let bounds: CGRect

    var rect: CGRect {
        CGRect(
            x: min(anchor.x, point.x), y: min(anchor.y, point.y), width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y))
    }

    var isUsable: Bool {
        rect.width >= Self.smallest && rect.height >= Self.smallest
    }

    var size: String {
        "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))"
    }

    init(from start: CGPoint, in bounds: CGRect) {
        self.bounds = bounds
        anchor = Self.clamp(start, to: bounds)
        point = anchor
    }

    private static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    mutating func drag(to end: CGPoint) {
        point = Self.clamp(end, to: bounds)
    }

    func badge(sized badge: CGSize) -> CGRect {
        let below = rect.minY - Self.badgeGap - badge.height
        let left = min(
            max(rect.maxX - Self.badgeInset - badge.width, bounds.minX), bounds.maxX - badge.width)
        return CGRect(
            x: left, y: below >= bounds.minY ? below : rect.minY + Self.badgeGap,
            width: badge.width, height: badge.height)
    }
}
