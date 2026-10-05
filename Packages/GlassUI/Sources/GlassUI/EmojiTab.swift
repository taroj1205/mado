import AppKit

final class EmojiTab: NSButton {
    private static let radius: CGFloat = 15

    var isOn = false {
        didSet {
            needsDisplay = true
            contentTintColor = isOn ? .labelColor : .secondaryLabelColor
            setAccessibilityValue(isOn)
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = isOn ? ResultRowView.fill.cgColor : nil
        layer?.cornerRadius = Self.radius
    }
}
