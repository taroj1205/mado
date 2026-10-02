import AppKit

final class RadialChoiceRow: NSButton {
    private static let height: CGFloat = 30
    private static let radius: CGFloat = 7
    private static let padding: CGFloat = 8
    private static let gap: CGFloat = 10
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 11.5
    private static let checkSize: CGFloat = 11
    private static let chosenAlpha: CGFloat = 0.35

    let choice: RadialEditor.Choice
    var isChosen = false {
        didSet {
            state = isChosen ? .on : .off
            setAccessibilityValue(isChosen ? 1 : 0)
            check.alphaValue = isChosen ? 1 : 0
            needsDisplay = true
        }
    }

    private let check = NSImageView(
        image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) ?? NSImage())

    override var focusRingMaskBounds: NSRect { bounds }

    init(_ choice: RadialEditor.Choice, target: AnyObject, action: Selector) {
        self.choice = choice
        super.init(frame: .zero)
        setButtonType(.radio)
        isBordered = false
        title = ""
        self.target = target
        self.action = action
        setAccessibilityLabel(choice.title)
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        setAccessibilityHelp(choice.detail)
        layOut()
        isChosen = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview = unsafe superview else { return nil }
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func accessibilityPerformPress() -> Bool {
        performClick(nil)
        return true
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()
    }

    override func draw(_: NSRect) {
        guard isChosen else { return }
        NSColor.controlAccentColor.withAlphaComponent(Self.chosenAlpha).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()
    }

    private func layOut() {
        let glyph = RadialGlyphView()
        glyph.area = choice.glyph
        let name = NSTextField(labelWithString: choice.title)
        name.font = .systemFont(ofSize: Self.titleSize)
        name.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        name.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        let detail = NSTextField(labelWithString: choice.detail ?? "")
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        check.symbolConfiguration = .init(pointSize: Self.checkSize, weight: .bold)
        check.contentTintColor = .labelColor
        let stack = NSStackView(views: [glyph, name, detail, check])
        stack.distribution = .fill
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
