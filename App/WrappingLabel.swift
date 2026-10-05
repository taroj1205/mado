import AppKit

final class WrappingLabel: NSTextField {
    convenience init(_ string: String, size: CGFloat, color: NSColor) {
        self.init(wrappingLabelWithString: string)
        font = .systemFont(ofSize: size)
        textColor = color
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard preferredMaxLayoutWidth != newSize.width else { return }
        preferredMaxLayoutWidth = newSize.width
        invalidateIntrinsicContentSize()
    }
}
