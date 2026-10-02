import AppKit

final class SwitcherThumbnail: NSView {
    private static let radius: CGFloat = 10
    private static let hairline: CGFloat = 0.5
    private static let half: CGFloat = 0.5
    private static let dotSize: CGFloat = 5
    private static let dotGap: CGFloat = 3
    private static let dotInset: CGFloat = 8
    private static let barLeading: CGFloat = 10
    private static let barTop: CGFloat = 24
    private static let barHeight: CGFloat = 5
    private static let barGap: CGFloat = 6
    private static let firstBarWidth: CGFloat = 0.80
    private static let secondBarWidth: CGFloat = 0.60
    private static let thirdBarWidth: CGFloat = 0.72
    private static let firstBarAlpha = (dark: 0.14, light: 0.12)
    private static let barAlpha = (dark: 0.10, light: 0.08)
    private static let iconSize: CGFloat = 28
    private static let iconInset: CGFloat = 6
    private static let fillGrey: CGFloat = 0.173
    private static let fillBlue: CGFloat = 0.204
    private static let fillAlpha = (dark: 0.95, light: 0.85)
    private static let edgeAlpha: CGFloat = 0.08
    private static let dots: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
    private static let darkFill = NSColor(
        srgbRed: fillGrey, green: fillGrey, blue: fillBlue, alpha: fillAlpha.dark)
    private static let lightFill = NSColor.white.withAlphaComponent(fillAlpha.light)

    let icon = NSImageView()
    private let preview = NSImageView()

    var image: CGImage? {
        didSet {
            preview.image = image.map { NSImage(cgImage: $0, size: .zero) }
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.wantsLayer = true
        preview.layer?.cornerRadius = Self.radius
        preview.layer?.cornerCurve = .continuous
        preview.layer?.masksToBounds = true
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(preview)
        addSubview(icon)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        preview.frame = bounds.insetBy(dx: Self.hairline, dy: Self.hairline)
        icon.frame = CGRect(
            x: bounds.maxX - Self.iconInset - Self.iconSize,
            y: bounds.maxY - Self.iconInset - Self.iconSize, width: Self.iconSize,
            height: Self.iconSize)
    }

    override func draw(_: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let ink: NSColor = dark ? .white : .black
        let shape = NSBezierPath(
            roundedRect: bounds.insetBy(dx: Self.hairline, dy: Self.hairline),
            xRadius: Self.radius, yRadius: Self.radius)
        (dark ? Self.darkFill : Self.lightFill).setFill()
        shape.fill()
        ink.withAlphaComponent(Self.edgeAlpha).setStroke()
        shape.stroke()
        guard image == nil else { return }
        for (index, colour) in Self.dots.enumerated() {
            colour.setFill()
            let left = Self.dotInset + CGFloat(index) * (Self.dotSize + Self.dotGap)
            NSBezierPath(
                ovalIn: CGRect(
                    x: left, y: Self.dotInset, width: Self.dotSize, height: Self.dotSize)
            ).fill()
        }
        let span = bounds.insetBy(dx: Self.barLeading, dy: 0).width
        let corner = Self.barHeight * Self.half
        let bars = [
            (Self.firstBarWidth, Self.firstBarAlpha), (Self.secondBarWidth, Self.barAlpha),
            (Self.thirdBarWidth, Self.barAlpha),
        ]
        for (index, (width, alpha)) in bars.enumerated() {
            ink.withAlphaComponent(dark ? alpha.dark : alpha.light).setFill()
            let top = Self.barTop + CGFloat(index) * (Self.barHeight + Self.barGap)
            let rect = CGRect(
                x: Self.barLeading, y: top, width: span * width, height: Self.barHeight)
            NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner).fill()
        }
    }
}
