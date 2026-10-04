import AppKit

struct LiquidShape {
    private static let droplet: CGFloat = 16
    private static let stretch: CFTimeInterval = 0.42
    private static let swell: CFTimeInterval = 0.34
    private static let fade: CFTimeInterval = 0.15
    private static let bounce: CGFloat = 0.3
    private static let pointTolerance: CGFloat = 0.1
    private static let alphaTolerance: CGFloat = 0.002
    private static let squashPerSpeed: CGFloat = 0.0001
    private static let mostSquash: CGFloat = 0.08
    private static let glassFadesBelow: CGFloat = 0.35
    private static let contentFadesBelow: CGFloat = 0.6

    let height: CGFloat
    private(set) var isShown = false
    private var wide = Self.spring(droplet)
    private var tall = Self.spring(droplet, duration: swell)
    private var opacity = Spring(0, duration: fade, bounce: 0, tolerance: alphaTolerance)

    var isSettled: Bool {
        wide.isSettled && tall.isSettled && opacity.isSettled
    }

    var size: CGSize {
        let squash = min(
            max(wide.velocity * Self.squashPerSpeed, -Self.mostSquash), Self.mostSquash)
        let squashed = tall.value * (1 - squash)
        return CGSize(width: max(wide.value, squashed), height: squashed)
    }

    var alpha: CGFloat {
        min(opacity.value, Self.clamp(grown / Self.glassFadesBelow))
    }

    var contentAlpha: CGFloat {
        Self.clamp((grown - Self.contentFadesBelow) / (1 - Self.contentFadesBelow))
    }

    private var grown: CGFloat {
        (tall.value - Self.droplet) / (height - Self.droplet)
    }

    init(height: CGFloat) {
        self.height = height
    }

    private static func spring(_ value: CGFloat, duration: CFTimeInterval = stretch) -> Spring {
        Spring(value, duration: duration, bounce: bounce, tolerance: pointTolerance)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    mutating func show(width: CGFloat, animated: Bool) {
        isShown = true
        wide.target = width
        tall.target = height
        opacity.target = 1
        if animated {
            opacity.snap()
        } else {
            wide.snap()
            tall.snap()
        }
    }

    mutating func hide(animated: Bool) {
        isShown = false
        if animated {
            wide.target = Self.droplet
            tall.target = Self.droplet
        } else {
            opacity.target = 0
        }
    }

    mutating func advance(by seconds: Double) {
        wide.advance(by: seconds)
        tall.advance(by: seconds)
        opacity.advance(by: seconds)
        if !isShown, isSettled {
            self = Self(height: height)
        }
    }
}
