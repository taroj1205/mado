public import AppKit

public final class RadialRing: NSView {
    public enum Highlight: Equatable, Sendable {
        case cancel
        case direction(degrees: CGFloat)
        case ring
    }

    static let side: CGFloat = 120
    static let half: CGFloat = 0.5
    static let centre = CGPoint(x: side * half, y: side * half)
    private static let dimmed: CGFloat = 0.75
    private static let closedScale: CGFloat = 0.7
    private static let fullTurn: CGFloat = 360
    private static let halfTurn = fullTurn * half
    private static let fade: CFTimeInterval = 0.12
    private static let travel: CFTimeInterval = 0.16
    private static let rotation = "transform.rotation.z"
    private static let openStart = (x: 0.2, y: 0.8)
    private static let turnStart = (x: 0.3, y: 0.7)
    private static let curveEnd = (x: 0.2, y: 1.0)
    private static let ease = CAMediaTimingFunction(name: .default)
    private static let opening = curve(from: openStart)
    private static let turning = curve(from: turnStart)

    private(set) var highlight = Highlight.cancel
    let glass = GlassView(shape: .capsule)
    let band = CAShapeLayer()
    let arc = CAShapeLayer()
    let cross = CAShapeLayer()
    let marks = NSView()
    let donut = CAShapeLayer()
    private(set) var arcDegrees: CGFloat?
    private var openings = 0

    private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        addDonut()
        addMarks()
        apply(animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public static func frame(centredOn point: CGPoint) -> NSRect {
        NSRect(
            x: (point.x - centre.x).rounded(), y: (point.y - centre.y).rounded(),
            width: side, height: side)
    }

    static func radians(_ degrees: CGFloat) -> CGFloat {
        degrees * .pi / halfTurn
    }

    private static func curve(from start: (x: Double, y: Double)) -> CAMediaTimingFunction {
        CAMediaTimingFunction(
            controlPoints: Float(start.x), Float(start.y), Float(curveEnd.x), Float(curveEnd.y))
    }

    public func select(_ next: Highlight) {
        guard next != highlight else { return }
        highlight = next
        apply(animated: animates)
    }

    public func appear() {
        openings += 1
        highlight = .cancel
        apply(animated: false)
        refreshAccent()
        open(true, then: nil)
    }

    public func disappear(then done: @escaping @MainActor @Sendable () -> Void) {
        let current = openings
        open(false) { [weak self] in
            if self?.openings == current { done() }
        }
    }

    override public func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = unsafe window?.backingScaleFactor ?? 1
        for layer in (marks.layer?.sublayers ?? []) + [donut] {
            layer.contentsScale = scale
        }
    }

    private func refreshAccent() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = NSColor.controlAccentColor.cgColor
            band.strokeColor = accent
            arc.strokeColor = accent
            arc.shadowColor = accent
        }
    }

    private func apply(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(Self.fade)
        CATransaction.setAnimationTimingFunction(Self.ease)
        cross.opacity = highlight == .cancel ? 1 : 0
        band.opacity = highlight == .ring ? 1 : 0
        if case .direction(let degrees) = highlight {
            arc.opacity = 1
            turn(to: degrees, animated: animated)
        } else {
            arc.opacity = 0
        }
        CATransaction.commit()
        let alpha = highlight == .cancel ? Self.dimmed : 1
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fade
                context.timingFunction = Self.ease
                glass.animator().alphaValue = alpha
            }
        } else {
            glass.alphaValue = alpha
        }
    }

    private func turn(to degrees: CGFloat, animated: Bool) {
        let current = arcDegrees ?? degrees
        let next = current + (degrees - current).remainder(dividingBy: Self.fullTurn)
        arcDegrees = next
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arc.setValue(Self.radians(next), forKeyPath: Self.rotation)
        CATransaction.commit()
        guard animated, next != current else { return }
        let spin = CABasicAnimation(keyPath: Self.rotation)
        spin.isAdditive = true
        spin.fromValue = Self.radians(current - next)
        spin.toValue = 0
        spin.duration = Self.travel
        spin.timingFunction = Self.turning
        arc.add(spin, forKey: nil)
    }

    private func open(_ isOpen: Bool, then done: (@MainActor @Sendable () -> Void)?) {
        guard let layer else { return }
        let shown = scaled(1, layer)
        let hidden = scaled(Self.closedScale, layer)
        layer.transform = isOpen ? shown : hidden
        guard animates else {
            alphaValue = isOpen ? 1 : 0
            done?()
            return
        }
        alphaValue = isOpen ? 0 : 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            context.timingFunction = Self.ease
            animator().alphaValue = isOpen ? 1 : 0
            let grow = CABasicAnimation(keyPath: "transform")
            grow.fromValue = isOpen ? hidden : shown
            grow.toValue = isOpen ? shown : hidden
            grow.duration = Self.travel
            grow.timingFunction = Self.opening
            layer.add(grow, forKey: "open")
        } completionHandler: {
            MainActor.assumeIsolated { done?() }
        }
    }

    private func scaled(_ scale: CGFloat, _ layer: CALayer) -> CATransform3D {
        let shiftX = bounds.width * (Self.half - layer.anchorPoint.x)
        let shiftY = bounds.height * (Self.half - layer.anchorPoint.y)
        let moved = CATransform3DMakeTranslation(shiftX, shiftY, 0)
        return CATransform3DTranslate(
            CATransform3DScale(moved, scale, scale, 1), -shiftX, -shiftY, 0)
    }
}
