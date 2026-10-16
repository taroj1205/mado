import AppKit

final class CameraButton: NSButton {
    static let side: CGFloat = 28
    private static let glyphSize: CGFloat = 13
    private static let half: CGFloat = 0.5

    var onPress: (() -> Void)?
    var isOn = false {
        didSet { refresh() }
    }

    private let symbol: String
    private let onSymbol: String

    init(symbol: String, onSymbol: String, label: String) {
        self.symbol = symbol
        self.onSymbol = onSymbol
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        isBordered = false
        imagePosition = .imageOnly
        target = self
        action = #selector(press)
        wantsLayer = true
        setAccessibilityLabel(label)
        HoverFill.install(in: self, radius: Self.side * Self.half)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
        ])
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    private func refresh() {
        image = NSImage(
            systemSymbolName: isOn ? onSymbol : symbol, accessibilityDescription: nil
        )?
        .withSymbolConfiguration(.init(pointSize: Self.glyphSize, weight: .semibold))
        contentTintColor = isOn ? .controlAccentColor : .labelColor
        if symbol != onSymbol {
            setAccessibilityRole(.checkBox)
            setAccessibilityValue(isOn)
        }
    }

    @objc
    private func press() {
        onPress?()
    }
}
