import AppKit

final class GlassSheen: NSView {
    typealias Ends = (start: CGFloat, end: CGFloat)
    typealias Stop = (alpha: CGFloat, location: CGFloat)

    struct Tone {
        let sheen: Ends
        let sheenMid: Stop
        let sheenClearAt: CGFloat
        let rim: Ends
        let rimMid: Stop
    }

    static let dark = Tone(
        sheen: darkSheen, sheenMid: darkSheenMid, sheenClearAt: darkSheenClearAt,
        rim: darkRim, rimMid: darkRimMid)
    static let light = Tone(
        sheen: lightSheen, sheenMid: lightSheenMid, sheenClearAt: lightSheenClearAt,
        rim: lightRim, rimMid: lightRimMid)

    private static let darkSheen: Ends = (0.10, 0.05)
    private static let darkSheenMid: Stop = (0.02, 0.26)
    private static let darkSheenClearAt: CGFloat = 0.58
    private static let lightSheen: Ends = (0.55, 0.25)
    private static let lightSheenMid: Stop = (0.12, 0.30)
    private static let lightSheenClearAt: CGFloat = 0.60
    private static let sheenAngle: CGFloat = -60
    private static let darkRim: Ends = (0.55, 0.18)
    private static let darkRimMid: Stop = (0.10, 0.5)
    private static let lightRim: Ends = (1, 0.75)
    private static let lightRimMid: Stop = (0.5, 0.5)
    private static let rimWidth: CGFloat = 1
    private static let rimAngle: CGFloat = -45

    var rimmed = false {
        didSet { needsDisplay = true }
    }

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
        if rimmed {
            drawRim(tone, outer: shape)
        }
    }

    private func drawRim(_ tone: Tone, outer: NSBezierPath) {
        let inner = max(0, radius - Self.rimWidth)
        let ring = NSBezierPath()
        ring.append(outer)
        ring.append(
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: Self.rimWidth, dy: Self.rimWidth),
                xRadius: inner, yRadius: inner))
        ring.windingRule = .evenOdd
        Self.gradient([(tone.rim.start, 0), tone.rimMid, (tone.rim.end, 1)])?
            .draw(in: ring, angle: Self.rimAngle)
    }
}
