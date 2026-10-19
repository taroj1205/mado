import AppKit
import Carbon.HIToolbox

final class TapChip: NSView {
    enum Style {
        case filled
        case warning
        case add
    }

    private static let height: CGFloat = 34
    private static let minimumWidth: CGFloat = 76
    private static let maximumWidth: CGFloat = 148
    private static let radius: CGFloat = 8
    private static let inset: CGFloat = 10
    private static let titleSize: CGFloat = 12.5
    private static let subtitleSize: CGFloat = 10
    private static let lineWidth: CGFloat = 1
    private static let half: CGFloat = 0.5
    private static let dash: CGFloat = 3
    private static let fillAlpha: CGFloat = 0.08
    private static let warningFillAlpha: CGFloat = 0.1
    private static let warningMark = "⚠︎ "
    private static let addTitle = "+ Add"
    private static let disabledAlpha: CGFloat = 0.5

    var onPress: (() -> Void)?
    var isEnabled = true {
        didSet { alphaValue = isEnabled ? 1 : Self.disabledAlpha }
    }

    private let style: Style

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { isEnabled }
    override var focusRingMaskBounds: NSRect { bounds }

    init(_ title: String, subtitle: String?, style: Style) {
        self.style = style
        super.init(frame: .zero)
        var lines = [Self.heading(title, style: style)]
        if let subtitle {
            lines.append(Self.caption(subtitle))
        }
        let text = NSStackView(views: lines)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        text.translatesAutoresizingMaskIntoConstraints = false
        text.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(text)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumWidth),
            widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumWidth),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func heading(_ title: String, style: Style) -> NSTextField {
        let heading = NSTextField(labelWithString: "")
        heading.font = .systemFont(ofSize: titleSize)
        heading.lineBreakMode = .byTruncatingTail
        heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        switch style {
        case .filled:
            heading.stringValue = title
            heading.textColor = .labelColor

        case .warning:
            heading.attributedStringValue = warning(title)

        case .add:
            heading.stringValue = addTitle
            heading.textColor = .tertiaryLabelColor
        }
        return heading
    }

    private static func caption(_ subtitle: String) -> NSTextField {
        let caption = NSTextField(labelWithString: subtitle)
        caption.font = .systemFont(ofSize: subtitleSize)
        caption.textColor = .secondaryLabelColor
        caption.lineBreakMode = .byTruncatingTail
        caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return caption
    }

    private static func warning(_ title: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: warningMark, attributes: [.foregroundColor: NSColor.systemOrange])
        text.append(
            NSAttributedString(string: title, attributes: [.foregroundColor: NSColor.labelColor]))
        return text
    }

    func show(_ menu: NSMenu) {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.maxY), in: self)
    }

    override func draw(_: NSRect) {
        let edge = Self.lineWidth * Self.half
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: edge, dy: edge), xRadius: Self.radius,
            yRadius: Self.radius)
        path.lineWidth = Self.lineWidth
        switch style {
        case .filled:
            NSColor.labelColor.withAlphaComponent(Self.fillAlpha).setFill()
            NSColor.separatorColor.setStroke()

        case .warning:
            NSColor.systemOrange.withAlphaComponent(Self.warningFillAlpha).setFill()
            NSColor.systemOrange.setStroke()

        case .add:
            NSColor.clear.setFill()
            NSColor.tertiaryLabelColor.setStroke()
            let pattern = [Self.dash, Self.dash]
            unsafe path.setLineDash(pattern, count: pattern.count, phase: 0)
        }
        path.fill()
        path.stroke()
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        press()
    }

    override func keyDown(with event: NSEvent) {
        guard [kVK_Space, kVK_Return].contains(Int(event.keyCode)) else {
            super.keyDown(with: event)
            return
        }
        press()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        press()
        return true
    }

    private func press() {
        guard isEnabled else { return }
        onPress?()
    }
}
