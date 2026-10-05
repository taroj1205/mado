import AppKit

final class WrappingLabel: NSTextField {
    override var intrinsicContentSize: NSSize {
        guard bounds.width > 0, let cell else { return super.intrinsicContentSize }
        let fitting = cell.cellSize(
            forBounds: NSRect(x: 0, y: 0, width: bounds.width, height: .greatestFiniteMagnitude))
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(fitting.height))
    }

    convenience init(_ string: String, size: CGFloat, color: NSColor) {
        self.init(wrappingLabelWithString: string)
        font = .systemFont(ofSize: size)
        textColor = color
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthChanged {
            invalidateIntrinsicContentSize()
        }
    }
}
