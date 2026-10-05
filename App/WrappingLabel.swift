import AppKit

final class WrappingLabel: NSTextField {
    convenience init(_ string: String, size: CGFloat, color: NSColor) {
        self.init(wrappingLabelWithString: string)
        font = .systemFont(ofSize: size)
        textColor = color
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    override func layout() {
        super.layout()
        guard preferredMaxLayoutWidth != bounds.width else { return }
        preferredMaxLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
    }
}
