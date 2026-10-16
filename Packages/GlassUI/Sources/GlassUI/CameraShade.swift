import AppKit

final class CameraShade: NSView {
    private static let alpha: CGFloat = 0.45

    override var mouseDownCanMoveWindow: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor.black.withAlphaComponent(Self.alpha).cgColor, NSColor.clear.cgColor,
        ]
        return gradient
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
