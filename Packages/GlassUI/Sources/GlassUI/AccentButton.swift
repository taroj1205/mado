import AppKit

final class AccentButton: NSButton {
    private static let height: CGFloat = 28
    private static let radius: CGFloat = 14
    private static let side: CGFloat = 14
    private static let fontSize: CGFloat = 13

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: attributedTitle.size().width.rounded(.up) + Self.side + Self.side,
            height: Self.height)
    }

    init(_ title: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        isBordered = false
        refusesFirstResponder = true
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.fontSize, weight: .semibold),
                .foregroundColor: NSColor.white,
            ])
        self.target = target
        self.action = action
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()
        super.draw(dirtyRect)
    }
}
