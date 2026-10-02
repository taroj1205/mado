import AppKit

final class SwitcherCard: NSView {
    private static let width: CGFloat = 168
    private static let padding: CGFloat = 8
    private static let radius: CGFloat = 18
    private static let ringWidth: CGFloat = 1.5
    private static let half: CGFloat = 0.5
    private static let thumbnailHeight: CGFloat = 100
    private static let textGap: CGFloat = 8
    private static let lineGap: CGFloat = 1
    private static let titleSize: CGFloat = 12.5
    private static let appSize: CGFloat = 11.5
    private static let selectedAlpha = (dark: 0.16, light: 0.07)
    private static let ringAlpha = (dark: 0.35, light: 0.16)
    private static let selectedFill = tone(selectedAlpha)
    private static let ring = tone(ringAlpha)

    static let thumbnailSize = CGSize(width: width - padding - padding, height: thumbnailHeight)
    static let size = CGSize(
        width: width,
        height: padding + thumbnailHeight + textGap + lineHeight(titleSize, .semibold) + lineGap
            + lineHeight(appSize, .regular) + padding)

    let thumbnail = SwitcherThumbnail()
    let title = NSTextField(labelWithString: "")
    let app = NSTextField(labelWithString: "")
    var onPress: (() -> Void)?
    var onHover: (() -> Void)?

    var selected = false {
        didSet {
            needsDisplay = true
            setAccessibilitySelected(selected)
        }
    }

    override var isFlipped: Bool { true }

    init(_ card: SwitcherOverlay.Card) {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.textColor = .labelColor
        title.stringValue = card.title
        app.font = .systemFont(ofSize: Self.appSize)
        app.textColor = .secondaryLabelColor
        app.stringValue = card.app
        thumbnail.icon.image = card.icon
        thumbnail.image = card.thumbnail
        let inner = Self.thumbnailSize.width
        thumbnail.frame = CGRect(
            origin: CGPoint(x: Self.padding, y: Self.padding), size: Self.thumbnailSize)
        let titleTop = thumbnail.frame.maxY + Self.textGap
        let titleHeight = Self.lineHeight(Self.titleSize, .semibold)
        title.frame = CGRect(x: Self.padding, y: titleTop, width: inner, height: titleHeight)
        app.frame = CGRect(
            x: Self.padding, y: titleTop + titleHeight + Self.lineGap, width: inner,
            height: Self.lineHeight(Self.appSize, .regular))
        for label in [title, app] {
            label.lineBreakMode = .byTruncatingTail
            label.setAccessibilityElement(false)
        }
        [thumbnail, title, app].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(card.app): \(card.title)")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func lineHeight(_ size: CGFloat, _ weight: NSFont.Weight) -> CGFloat {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: weight)
        return label.fittingSize.height
    }

    private static func tone(_ alpha: (dark: Double, light: Double)) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? .white.withAlphaComponent(alpha.dark) : .black.withAlphaComponent(alpha.light)
        }
    }

    override func draw(_: NSRect) {
        guard selected else { return }
        let shape = NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
        Self.selectedFill.setFill()
        shape.fill()
        let inset = Self.ringWidth * Self.half
        let edge = NSBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: Self.radius - inset,
            yRadius: Self.radius - inset)
        edge.lineWidth = Self.ringWidth
        Self.ring.setStroke()
        edge.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with _: NSEvent) {
        onHover?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}
