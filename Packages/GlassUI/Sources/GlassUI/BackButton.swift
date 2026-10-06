import AppKit

final class BackButton: NSButton {
    private static let size: CGFloat = 28
    private static let radius: CGFloat = 9
    private static let glyphSize: CGFloat = 12

    override var wantsUpdateLayer: Bool { true }

    init(target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isHidden = true
        let style = NSImage.SymbolConfiguration(pointSize: Self.glyphSize, weight: .bold)
        image = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Back")?
            .withSymbolConfiguration(style)
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = .labelColor
        wantsLayer = true
        HoverFill.install(in: self, radius: Self.radius)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        layer?.backgroundColor = ResultRowView.fill.cgColor
        layer?.cornerRadius = Self.radius
    }
}
