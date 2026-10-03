import AppKit

final class WidgetSkeleton: NSView {
    private static let radius: CGFloat = 5
    private static let edgeAlpha = (dark: 0.08, light: 0.05)
    private static let middleAlpha = (dark: 0.16, light: 0.10)
    private static let edge = WidgetTile.tone(.white, .black, edgeAlpha)
    private static let middle = WidgetTile.tone(.white, .black, middleAlpha)

    let fraction: CGFloat
    private let height: CGFloat

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    init(fraction: CGFloat, height: CGFloat) {
        self.fraction = fraction
        self.height = height
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        let bar = NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
        NSGradient(colors: [Self.edge, Self.middle, Self.edge])?.draw(in: bar, angle: 0)
    }
}
