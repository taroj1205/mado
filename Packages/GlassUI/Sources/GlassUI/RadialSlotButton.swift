import AppKit

final class RadialSlotButton: NSButton {
    enum Shape {
        case direction
        case hole
        case ring
    }

    private static let directionRadius: CGFloat = 12
    private static let lineWidth: CGFloat = 1.5
    private static let ringGlyphTop: CGFloat = 3
    private static let crossInset: CGFloat = 22.5
    private static let crossWidth: CGFloat = 1.4
    private static let badgeSize: CGFloat = 16
    private static let badgeOverhang: CGFloat = 5
    private static let badgeBorder: CGFloat = 1
    private static let badgeSymbolSize: CGFloat = 8
    private static let half: CGFloat = 0.5
    private static let chosenAlpha: CGFloat = 0.3
    private static let badgeGrey: CGFloat = 0.227
    private static let badgeBlue: CGFloat = 0.267
    private static let badgeEdgeAlpha: CGFloat = 0.18
    private static let glyphAlpha = (outline: 0.75, area: 0.92)
    private static let edgeAlpha = (dark: 0.12, light: 0.12)
    private static let directionAlpha = (dark: 0.08, light: 0.05)
    private static let ringAlpha = (dark: 0.06, light: 0.04)
    private static let holeAlpha = (dark: 0.35, light: 0.08)
    private static let badgeFill = NSColor(
        srgbRed: badgeGrey, green: badgeGrey, blue: badgeBlue, alpha: 1)
    private static let badgeEdge = NSColor.white.withAlphaComponent(badgeEdgeAlpha)
    private static let glyphColours = RadialGlyph.colours(
        outline: glyphAlpha.outline, area: glyphAlpha.area)
    private static let edge = adaptive(edgeAlpha)
    private static let directionFill = adaptive(directionAlpha)
    private static let ringFill = adaptive(ringAlpha)
    private static let holeFill = SheetForm.adaptive(
        dark: .black.withAlphaComponent(holeAlpha.dark),
        light: .black.withAlphaComponent(holeAlpha.light))

    let shape: Shape
    var area = CGRect.zero {
        didSet { needsDisplay = true }
    }
    var cycles = false {
        didSet { badge.isHidden = !cycles }
    }
    var isChosen = false {
        didSet {
            state = isChosen ? .on : .off
            setAccessibilityValue(isChosen ? 1 : 0)
            needsDisplay = true
        }
    }

    private let badge = NSView()

    private var outline: NSBezierPath {
        let rect = bounds.insetBy(dx: Self.lineWidth * Self.half, dy: Self.lineWidth * Self.half)
        return shape == .direction
            ? NSBezierPath(
                roundedRect: rect, xRadius: Self.directionRadius, yRadius: Self.directionRadius)
            : NSBezierPath(ovalIn: rect)
    }

    override var isFlipped: Bool { true }
    override var focusRingMaskBounds: NSRect { bounds }

    init(_ shape: Shape, side: CGFloat, target: AnyObject, action: Selector) {
        self.shape = shape
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        setButtonType(.radio)
        isBordered = false
        title = ""
        self.target = target
        self.action = action
        clipsToBounds = false
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        if shape == .direction {
            addBadge(side: side)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func adaptive(_ alpha: (dark: Double, light: Double)) -> NSColor {
        SheetForm.adaptive(
            dark: .white.withAlphaComponent(alpha.dark),
            light: .black.withAlphaComponent(alpha.light))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview = unsafe superview else { return nil }
        return outline.contains(convert(point, from: superview)) ? self : nil
    }

    override func accessibilityPerformPress() -> Bool {
        performClick(nil)
        return true
    }

    override func drawFocusRingMask() {
        outline.fill()
    }

    override func draw(_: NSRect) {
        let path = outline
        let fill: NSColor =
            if isChosen {
                .controlAccentColor.withAlphaComponent(Self.chosenAlpha)
            } else {
                switch shape {
                case .direction: Self.directionFill
                case .hole: Self.holeFill
                case .ring: Self.ringFill
                }
            }
        fill.setFill()
        path.fill()
        (isChosen ? NSColor.controlAccentColor : Self.edge).setStroke()
        path.lineWidth = Self.lineWidth
        path.stroke()
        switch shape {
        case .direction:
            RadialGlyph.draw(
                area,
                at: CGPoint(
                    x: (bounds.width - RadialGlyph.size.width) * Self.half,
                    y: (bounds.height - RadialGlyph.size.height) * Self.half),
                colours: Self.glyphColours)

        case .ring:
            RadialGlyph.draw(
                area,
                at: CGPoint(
                    x: (bounds.width - RadialGlyph.size.width) * Self.half, y: Self.ringGlyphTop),
                colours: Self.glyphColours)

        case .hole:
            drawCross()
        }
    }

    private func drawCross() {
        let box = bounds.insetBy(dx: Self.crossInset, dy: Self.crossInset)
        let cross = NSBezierPath()
        cross.move(to: CGPoint(x: box.minX, y: box.minY))
        cross.line(to: CGPoint(x: box.maxX, y: box.maxY))
        cross.move(to: CGPoint(x: box.maxX, y: box.minY))
        cross.line(to: CGPoint(x: box.minX, y: box.maxY))
        cross.lineWidth = Self.crossWidth
        cross.lineCapStyle = .round
        NSColor.secondaryLabelColor.setStroke()
        cross.stroke()
    }

    private func addBadge(side: CGFloat) {
        badge.frame = NSRect(
            x: side - Self.badgeSize + Self.badgeOverhang, y: -Self.badgeOverhang,
            width: Self.badgeSize, height: Self.badgeSize)
        badge.wantsLayer = true
        badge.layer?.backgroundColor = Self.badgeFill.cgColor
        badge.layer?.borderColor = Self.badgeEdge.cgColor
        badge.layer?.borderWidth = Self.badgeBorder
        badge.layer?.cornerRadius = Self.badgeSize * Self.half
        badge.isHidden = true
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "arrow.2.circlepath", accessibilityDescription: nil)
                ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: Self.badgeSymbolSize, weight: .bold)
        icon.contentTintColor = .white
        icon.frame = badge.bounds
        badge.addSubview(icon)
        addSubview(badge)
    }
}
