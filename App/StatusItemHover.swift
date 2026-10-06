import AppKit

@MainActor
final class StatusItemHover: NSView {
    private static let radius: CGFloat = 6
    private static let alpha: CGFloat = 0.14

    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Self.radius
        layer?.cornerCurve = .continuous
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func install(on button: NSStatusBarButton?) {
        guard let button else { return }
        let hover = StatusItemHover(frame: .zero)
        hover.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hover, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            hover.topAnchor.constraint(equalTo: button.topAnchor),
            hover.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hover.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hover.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        ])
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor =
                isHovered ? NSColor.labelColor.withAlphaComponent(Self.alpha).cgColor : nil
        }
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = NSEvent.pressedMouseButtons == 0
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
    }
}
