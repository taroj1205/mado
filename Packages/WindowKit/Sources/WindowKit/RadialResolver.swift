public import CoreGraphics

public struct RadialResolver: Sendable {
    public enum Direction: Sendable {
        case bottom, bottomLeft, bottomRight, left, right, top, topLeft, topRight
    }

    public enum Zone: Equatable, Sendable {
        case cancel
        case direction(Direction)
        case ring
    }

    private static let directions: [Direction] = [
        .right, .topRight, .top, .topLeft, .left, .bottomLeft, .bottom, .bottomRight,
    ]
    private static let ringEntry: CGFloat = 28
    private static let holeEntry: CGFloat = 24
    private static let outerEntry: CGFloat = 62
    private static let outerExit: CGFloat = 58
    private static let slackDegrees: CGFloat = 6
    private static let half: CGFloat = 0.5
    private static let fullTurn: CGFloat = 360
    private static let halfTurn = fullTurn * half
    private static let sectorDegrees = fullTurn / CGFloat(directions.count)

    private let origin: CGPoint
    public private(set) var zone = Zone.cancel

    public init(origin: CGPoint) {
        self.origin = origin
    }

    public mutating func update(pointer: CGPoint) {
        let offset = CGVector(dx: pointer.x - origin.x, dy: pointer.y - origin.y)
        let distance = hypot(offset.dx, offset.dy)
        let holeLimit = zone == .cancel ? Self.ringEntry : Self.holeEntry
        let ringLimit = if case .direction = zone { Self.outerExit } else { Self.outerEntry }
        if distance < holeLimit {
            zone = .cancel
        } else if distance <= ringLimit {
            zone = .ring
        } else {
            zone = .direction(direction(at: atan2(offset.dy, offset.dx) * Self.halfTurn / .pi))
        }
    }

    private func direction(at degrees: CGFloat) -> Direction {
        if case .direction(let held) = zone, let index = Self.directions.firstIndex(of: held) {
            let offset = (degrees - CGFloat(index) * Self.sectorDegrees)
                .remainder(dividingBy: Self.fullTurn)
            if abs(offset) <= Self.sectorDegrees * Self.half + Self.slackDegrees { return held }
        }
        let count = Self.directions.count
        let index = Int((degrees / Self.sectorDegrees).rounded())
        return Self.directions[(index + count) % count]
    }
}
