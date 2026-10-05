import AppKit

final class LyricsCardButton: NSButton {
    static let side: CGFloat = 22

    var onPress: (() -> Void)?
    private let size: CGFloat

    init(size: CGFloat, label: String) {
        self.size = size
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .labelColor
        target = self
        action = #selector(press)
        setAccessibilityLabel(label)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    func show(symbol: String, label: String) {
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        setAccessibilityLabel(label)
    }

    @objc
    private func press() {
        onPress?()
    }
}
