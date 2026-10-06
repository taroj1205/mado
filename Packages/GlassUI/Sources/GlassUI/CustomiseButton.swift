import AppKit

final class CustomiseButton: NSView {
    private static let size: CGFloat = 36
    private static let radius: CGFloat = 12
    private static let edge: CGFloat = 0.5
    private static let dash: CGFloat = 3
    private static let symbolSize: CGFloat = 11
    private static let dashAlpha = (dark: 0.24, light: 0.22)
    private static let dashColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(dashAlpha.dark)
            : .black.withAlphaComponent(dashAlpha.light)
    }

    var onPress: (() -> Void)?

    var isOpen = false {
        didSet {
            needsDisplay = true
            setAccessibilityExpanded(isOpen)
        }
    }

    init() {
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .semibold)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        HoverFill.install(in: self, radius: Self.radius)
        addSubview(icon)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Customise status bar")
        setAccessibilityExpanded(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: Self.edge, dy: Self.edge), xRadius: Self.radius,
            yRadius: Self.radius)
        if isOpen {
            StatusPill.selectedFill.setFill()
            path.fill()
        }
        let pattern = [Self.dash, Self.dash]
        unsafe path.setLineDash(pattern, count: pattern.count, phase: 0)
        Self.dashColor.setStroke()
        path.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}
