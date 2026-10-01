import AppKit

final class GlassSheen: NSView {
    typealias Ends = (start: CGFloat, end: CGFloat)
    typealias Stop = (alpha: CGFloat, location: CGFloat)

    struct Tone {
        let sheen: Ends
        let sheenMid: Stop
        let sheenClearAt: CGFloat
    }

    static let dark = Tone(
        sheen: darkSheen, sheenMid: darkSheenMid, sheenClearAt: darkSheenClearAt)
    static let light = Tone(
        sheen: lightSheen, sheenMid: lightSheenMid, sheenClearAt: lightSheenClearAt)

    private static let darkSheen: Ends = (0.10, 0.05)
    private static let darkSheenMid: Stop = (0.02, 0.26)
    private static let darkSheenClearAt: CGFloat = 0.58
    private static let lightSheen: Ends = (0.55, 0.25)
    private static let lightSheenMid: Stop = (0.12, 0.30)
    private static let lightSheenClearAt: CGFloat = 0.60
    private static let sheenAngle: CGFloat = -60

    var radius: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        layerContentsRedrawPolicy = .duringViewResize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func tone(for appearance: NSAppearance) -> Tone {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }

    private static func gradient(_ stops: [Stop]) -> NSGradient? {
        unsafe NSGradient(
            colors: stops.map { NSColor.white.withAlphaComponent($0.alpha) },
            atLocations: stops.map(\.location), colorSpace: .sRGB)
    }

    override func draw(_: NSRect) {
        let tone = Self.tone(for: effectiveAppearance)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        Self.gradient([
            (tone.sheen.start, 0), tone.sheenMid, (0, tone.sheenClearAt), (tone.sheen.end, 1),
        ])?
        .draw(in: shape, angle: Self.sheenAngle)
    }
}
