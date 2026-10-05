import AppKit

final class WidgetSpotLabel: NSView {
    private static let height: CGFloat = 24
    private static let inset: CGFloat = 10
    private static let gap: CGFloat = 6
    private static let fontSize: CGFloat = 12
    private static let symbolSize: CGFloat = 11
    private static let half: CGFloat = 0.5

    private let icon = NSImageView()
    private let text = NSTextField(labelWithString: "")

    var title: String { text.stringValue }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Self.height * Self.half
        text.font = .systemFont(ofSize: Self.fontSize, weight: .semibold)
        text.textColor = .white
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .bold)
        icon.contentTintColor = .white
        let stack = NSStackView(views: [icon, text])
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.inset, bottom: 0, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: Self.height),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ title: String, symbol: String, tint: NSColor) {
        text.stringValue = title
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        layer?.backgroundColor = tint.cgColor
        setAccessibilityLabel(title)
    }
}
