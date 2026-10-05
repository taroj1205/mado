import AppKit

final class CheckCircle: NSView {
    static let size: CGFloat = 18
    private static let ring: CGFloat = 16
    private static let markSize: CGFloat = 9
    private static let half: CGFloat = 0.5
    private static let ringColour = NSColor.tertiaryLabelColor

    private static var mark: NSImage? {
        NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: markSize, weight: .heavy)
                    .applying(.init(paletteColors: [.white])))
    }

    var isChecked = false {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        guard isChecked else {
            let inset = (Self.size - Self.ring) * Self.half
            Self.ringColour.setStroke()
            NSBezierPath(ovalIn: bounds.insetBy(dx: inset + Self.half, dy: inset + Self.half))
                .stroke()
            return
        }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        guard let mark = Self.mark else { return }
        mark.draw(
            at: NSPoint(
                x: bounds.midX - mark.size.width * Self.half,
                y: bounds.midY - mark.size.height * Self.half),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
}
