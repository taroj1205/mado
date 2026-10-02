public import AppKit

@MainActor
public final class SnapPreview {
    private static let radius: CGFloat = 14
    private static let border: CGFloat = 4
    private static let tint: CGFloat = 0.12
    private static let hairline: CGFloat = 0.5
    private static let hairlineAlpha: CGFloat = 0.35
    private static let shadowAlpha: CGFloat = 0.28
    private static let shadowBlur: CGFloat = 40
    private static let shadowDrop: CGFloat = 12
    private static let margin = shadowBlur + shadowDrop
    private static let cap = margin + radius + shadowBlur
    private static let side = cap + 1 + cap
    private static let half: CGFloat = 0.5
    private static let fade: CFTimeInterval = 0.12
    private static let settle: CFTimeInterval = 0.16

    public let panel = OverlayPanel()
    let outline = CALayer()
    private var origin = CGRect.zero
    private var isEnding = false
    private var drawn: (accent: NSColor, scale: CGFloat)?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    var box: CGRect {
        outline.frame.insetBy(dx: Self.margin, dy: Self.margin)
    }

    public init() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.addSublayer(outline)
        panel.contentView = view
        outline.opacity = 0
        let unit = Self.cap / Self.side
        outline.contentsCenter = CGRect(
            x: unit, y: unit, width: 1 / Self.side, height: 1 / Self.side)
    }

    private static func image(accent: NSColor) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { bounds in
            let rect = bounds.insetBy(dx: margin, dy: margin)
            let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -shadowDrop)
            shadow.shadowBlurRadius = shadowBlur
            shadow.shadowColor = .black.withAlphaComponent(shadowAlpha)
            shadow.set()
            NSColor.black.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            shape.fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            stroke(
                rect, outset: hairline * half, width: hairline,
                .black.withAlphaComponent(hairlineAlpha))
            accent.withAlphaComponent(tint).setFill()
            shape.fill()
            stroke(rect, outset: -border * half, width: border, accent)
            return true
        }
    }

    private static func stroke(_ rect: CGRect, outset: CGFloat, width: CGFloat, _ color: NSColor) {
        let path = NSBezierPath(
            roundedRect: rect.insetBy(dx: -outset, dy: -outset),
            xRadius: radius + outset, yRadius: radius + outset)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    public func begin(from window: CGRect, on screen: NSScreen) {
        isEnding = false
        panel.setFrame(screen.frame, display: false)
        origin = window.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        draw(scale: screen.backingScaleFactor)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.removeAllAnimations()
        outline.frame = origin.insetBy(dx: -Self.margin, dy: -Self.margin)
        outline.opacity = 0
        CATransaction.commit()
        panel.orderFrontRegardless()
    }

    public func show(_ target: CGRect?) {
        let frame = target?.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY) ?? origin
        change(
            to: frame.insetBy(dx: -Self.margin, dy: -Self.margin), opacity: target == nil ? 0 : 1)
    }

    public func end() {
        guard panel.isVisible else { return }
        isEnding = true
        change(to: outline.frame, opacity: 0) { [weak self] in
            guard let self, isEnding else { return }
            panel.orderOut(nil)
        }
    }

    private func draw(scale: CGFloat) {
        let accent = NSColor.controlAccentColor
        guard drawn?.accent != accent || drawn?.scale != scale else { return }
        drawn = (accent, scale)
        outline.contentsScale = scale
        outline.contents = Self.image(accent: accent).layerContents(forContentsScale: scale)
    }

    private func change(
        to frame: CGRect, opacity: Float, completion: (@MainActor () -> Void)? = nil
    ) {
        let current = outline.presentation() ?? outline
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(
            completion.map { done in { MainActor.assumeIsolated(done) } })
        if !reducesMotion() {
            if frame != outline.frame {
                spring("position", from: current.position)
                spring("bounds", from: current.bounds)
            }
            if opacity != outline.opacity {
                let fading = CABasicAnimation(keyPath: "opacity")
                fading.fromValue = current.opacity
                fading.duration = Self.fade
                fading.timingFunction = CAMediaTimingFunction(name: .default)
                outline.add(fading, forKey: "opacity")
            }
        }
        outline.frame = frame
        outline.opacity = opacity
        CATransaction.commit()
    }

    private func spring(_ key: String, from value: Any) {
        let spring = CASpringAnimation(perceptualDuration: Self.settle, bounce: 0)
        spring.keyPath = key
        spring.fromValue = value
        spring.duration = spring.settlingDuration
        outline.add(spring, forKey: key)
    }
}
