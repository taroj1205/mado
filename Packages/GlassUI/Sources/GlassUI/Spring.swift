import AppKit

struct Spring {
    private static let stepsPerSecond: Double = 240

    var target: CGFloat
    private(set) var value: CGFloat
    private(set) var velocity: CGFloat = 0
    private let stiffness: CGFloat
    private let damping: CGFloat
    private let tolerance: CGFloat
    private let slowest: CGFloat

    var isSettled: Bool {
        value == target && velocity == 0
    }

    init(_ value: CGFloat, duration: CFTimeInterval, bounce: CGFloat, tolerance: CGFloat) {
        let model = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
        stiffness = model.stiffness / model.mass
        damping = model.damping / model.mass
        self.value = value
        self.tolerance = tolerance
        slowest = tolerance * stiffness.squareRoot()
        target = value
    }

    mutating func snap() {
        value = target
        velocity = 0
    }

    mutating func advance(by seconds: Double) {
        var left = seconds
        while left > 0, !isSettled {
            let step = min(left, 1 / Self.stepsPerSecond)
            velocity += (stiffness * (target - value) - damping * velocity) * step
            value += velocity * step
            left -= step
            if abs(target - value) < tolerance, abs(velocity) < slowest {
                snap()
            }
        }
    }
}
