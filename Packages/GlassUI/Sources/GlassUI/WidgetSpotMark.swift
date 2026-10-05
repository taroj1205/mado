import AppKit

final class WidgetSpotMark: NSView {
    static let target: CGFloat = 30

    private static let bar: CGFloat = 6
    private static let length = (rest: 16.0, hot: 20.0, on: 24.0)
    private static let barRadius: CGFloat = 4
    private static let haloRadius: CGFloat = 9
    private static let glow: CGFloat = 10
    private static let panelRadius: CGFloat = 13
    private static let ring: CGFloat = 2
    private static let half: CGFloat = 0.5
    private static let haloAlpha = (dark: 0.08, light: 0.05)
    private static let frameAlpha = (dark: 0.16, light: 0.14)
    private static let miniAlpha = (dark: 0.05, light: 0.55)
    private static let lineAlpha = (dark: 0.18, light: 0.16)
    private static let faintAlpha = (dark: 0.09, light: 0.07)
    private static let halo = WidgetTile.tone(.white, .black, haloAlpha)
    private static let frameColour = WidgetTile.tone(.white, .black, frameAlpha)
    private static let mini = WidgetTile.tone(.white, .white, miniAlpha)
    private static let line = WidgetTile.tone(.white, .black, lineAlpha)
    private static let faint = WidgetTile.tone(.white, .black, faintAlpha)
    private static let pad: CGFloat = 10
    private static let header = (top: 9.0, width: 56.0, height: 5.0)
    private static let divider: CGFloat = 21
    private static let block = (top: 28.0, width: 46.0, height: 16.0)
    private static let chip = (left: 60.0, width: 22.0)
    private static let rules = (top: 52.0, gap: 9.0, height: 4.0, long: 104.0, short: 80.0)
    private static let ruleRadius: CGFloat = 2

    let spot: WidgetGrid.Spot
    var onPick: ((WidgetGrid.Spot) -> Void)?
    var onHover: ((WidgetGrid.Spot?) -> Void)?

    var isOn = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(isOn)
        }
    }

    var isHot = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    init(_ spot: WidgetGrid.Spot) {
        self.spot = spot
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        setAccessibilityLabel(spot.title)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func fill(_ rect: NSRect, radius: CGFloat, with colour: NSColor) {
        colour.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    override func draw(_: NSRect) {
        if spot == .panel {
            drawPanel()
        } else {
            drawBar()
        }
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPick?(spot)
    }

    override func mouseEntered(with _: NSEvent) {
        onHover?(spot)
    }

    override func mouseExited(with _: NSEvent) {
        onHover?(nil)
    }

    override func accessibilityPerformPress() -> Bool {
        onPick?(spot)
        return true
    }

    private func drawBar() {
        if isHot, !isOn {
            Self.fill(bounds, radius: Self.haloRadius, with: Self.halo)
        }
        let long = isOn ? Self.length.on : isHot ? Self.length.hot : Self.length.rest
        let flat = spot.side == .above
        let width = flat ? long : Self.bar
        let height = flat ? Self.bar : long
        let rect = NSRect(
            x: bounds.midX - width * Self.half, y: bounds.midY - height * Self.half, width: width,
            height: height)
        if isOn {
            let shade = NSShadow()
            shade.shadowBlurRadius = Self.glow
            shade.shadowColor = .controlAccentColor
            shade.set()
        }
        let colour: NSColor =
            isOn ? .controlAccentColor : isHot ? .secondaryLabelColor : .tertiaryLabelColor
        Self.fill(rect, radius: Self.barRadius, with: colour)
    }

    private func drawPanel() {
        let card = bounds.insetBy(dx: Self.ring, dy: Self.ring)
        let shape = NSBezierPath(
            roundedRect: card, xRadius: Self.panelRadius, yRadius: Self.panelRadius)
        Self.mini.setFill()
        shape.fill()
        let edge: NSColor =
            isOn ? .controlAccentColor : isHot ? .secondaryLabelColor : Self.frameColour
        edge.setStroke()
        shape.lineWidth = isOn ? Self.ring : 1
        shape.stroke()
        let left = card.minX + Self.pad
        Self.frameColour.setFill()
        NSRect(x: card.minX, y: card.minY + Self.divider, width: card.width, height: 1).fill()
        Self.fill(
            NSRect(
                x: left, y: card.minY + Self.header.top, width: Self.header.width,
                height: Self.header.height),
            radius: Self.ruleRadius, with: Self.line)
        Self.fill(
            NSRect(
                x: left, y: card.minY + Self.block.top, width: Self.block.width,
                height: Self.block.height),
            radius: Self.barRadius, with: isOn ? .controlAccentColor : Self.line)
        Self.fill(
            NSRect(
                x: card.minX + Self.chip.left, y: card.minY + Self.block.top,
                width: Self.chip.width, height: Self.block.height),
            radius: Self.barRadius, with: Self.line)
        for (index, width) in [Self.rules.long, Self.rules.short].enumerated() {
            let top = card.minY + Self.rules.top + CGFloat(index) * Self.rules.gap
            Self.fill(
                NSRect(x: left, y: top, width: width, height: Self.rules.height),
                radius: Self.ruleRadius, with: Self.faint)
        }
    }
}
