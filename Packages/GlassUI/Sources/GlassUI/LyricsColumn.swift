import AppKit

final class LyricsColumn: NSView {
    struct Look {
        let pitch: CGFloat
        let size: CGFloat
        let rest: CGFloat
    }

    private static let falloff = 0.55
    private static let reach = 4
    private static let plainOpacity: Float = 0.85
    private static let scrollSeconds = 0.6
    private static let curveStart = (x: 0.2, y: 0.8)
    private static let curveEnd = (x: 0.2, y: 1.0)
    private static let scrollCurve = CAMediaTimingFunction(
        controlPoints: Float(curveStart.x), Float(curveStart.y), Float(curveEnd.x),
        Float(curveEnd.y))
    private static let fadeStops: (top: Double, bottom: Double) = (0.12, 0.84)
    private static let lineHeight: CGFloat = 1.3
    private static let half: CGFloat = 0.5
    private static let fallbackScale: CGFloat = 2

    let look: Look
    private var rows: [CATextLayer] = []
    private let fill = CATextLayer()
    private let wipe = WipeMask()
    private let fade = CAGradientLayer()
    private var lines: [String] = []
    private var current: Int?
    private var settled = false

    override var wantsUpdateLayer: Bool {
        true
    }

    private var restScale: CGFloat {
        look.rest / look.size
    }

    private var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var textHeight: CGFloat {
        look.size * Self.lineHeight
    }

    init(look: Look) {
        self.look = look
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = true
        fade.colors = [NSColor.clear, .black, .black, .clear].map(\.cgColor)
        let stops = Self.fadeStops
        fade.locations = [0, stops.top, stops.bottom, 1].map { .init(value: $0) }
        layer?.mask = fade
        style(fill)
        fill.mask = wipe
        fill.isHidden = true
        layer?.addSublayer(fill)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly {
            fade.frame = bounds
            place(animated: false)
        }
    }

    override func updateLayer() {
        paint()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    func line(at point: NSPoint) -> Int? {
        guard let current else { return nil }
        let halfPitch = look.pitch * Self.half
        return rows.indices.first { index in
            abs(index - current) <= Self.reach
                && abs(point.y - target(of: index, focus: current).y) <= halfPitch
        }
    }

    func show(
        _ next: [String], current: Int?, progress: Double, remaining: Double?, playing: Bool
    ) {
        let changed = next != lines
        let moved = changed || current != self.current
        if changed {
            lines = next
            rebuild()
        }
        let previous = self.current
        self.current = current
        if moved, let current, rows.indices.contains(current) {
            startFill(at: current, from: previous)
        }
        place(animated: moved && settled && !changed && !reducesMotion)
        settled = true
        fill.isHidden = !(current.map(hasText) ?? false)
        wipe.run(from: progress, remaining: remaining, playing: playing, restart: moved)
    }

    private func hasText(_ index: Int) -> Bool {
        lines.indices.contains(index) && !lines[index].isEmpty
    }

    private func style(_ text: CATextLayer) {
        text.font = NSFont.systemFont(ofSize: look.size, weight: .semibold)
        text.fontSize = look.size
        text.alignmentMode = .left
        text.truncationMode = .end
        text.anchorPoint = CGPoint(x: 0, y: Self.half)
        text.contentsScale = unsafe window?.backingScaleFactor ?? Self.fallbackScale
    }

    private func rebuild() {
        rows.forEach { $0.removeFromSuperlayer() }
        rows = lines.map { text in
            let row = CATextLayer()
            style(row)
            row.string = text
            layer?.insertSublayer(row, below: fill)
            return row
        }
        settled = false
    }

    private func paint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            fill.foregroundColor = NSColor.labelColor.cgColor
            let base = NSColor.secondaryLabelColor.cgColor
            rows.forEach { $0.foregroundColor = base }
        }
    }

    private func target(of index: Int, focus: Int?) -> (y: CGFloat, scale: CGFloat) {
        guard let focus else {
            let top = bounds.height - look.pitch * Self.half
            return (top - CGFloat(index) * look.pitch, restScale)
        }
        return (bounds.midY + CGFloat(focus - index) * look.pitch, index == focus ? 1 : restScale)
    }

    private func startFill(at index: Int, from previous: Int?) {
        CATransaction.quietly {
            fill.string = lines[index]
            let start = target(of: index, focus: previous ?? index)
            fill.position = CGPoint(x: 0, y: start.y)
            fill.transform = CATransform3DMakeScale(start.scale, start.scale, 1)
            fill.opacity = 0
            wipe.fit(width: textWidth(of: lines[index]), height: textHeight)
        }
    }

    private func textWidth(of text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: look.size, weight: .semibold)
        let width = NSAttributedString(string: text, attributes: [.font: font]).size().width
        return min(width, bounds.width)
    }

    private func place(animated: Bool) {
        paint()
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(Self.scrollSeconds)
            CATransaction.setAnimationTimingFunction(Self.scrollCurve)
        } else {
            CATransaction.setDisableActions(true)
        }
        for (index, row) in rows.enumerated() {
            let spot = target(of: index, focus: current)
            row.bounds = CGRect(
                x: 0, y: 0, width: bounds.width / spot.scale, height: textHeight)
            row.position = CGPoint(x: 0, y: spot.y)
            row.transform = CATransform3DMakeScale(spot.scale, spot.scale, 1)
            row.opacity = opacity(of: index)
        }
        if let current, rows.indices.contains(current) {
            fill.bounds = rows[current].bounds
            fill.position = rows[current].position
            fill.transform = CATransform3DIdentity
            fill.opacity = 1
        }
        CATransaction.commit()
    }

    private func opacity(of index: Int) -> Float {
        guard let current else { return Self.plainOpacity }
        let distance = abs(index - current)
        return distance <= Self.reach ? Float(pow(Self.falloff, Double(distance))) : 0
    }
}
