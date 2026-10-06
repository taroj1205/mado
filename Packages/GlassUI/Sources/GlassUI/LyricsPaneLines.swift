import AppKit

final class LyricsPaneLines: NSView {
    enum Mode {
        case synced
        case plain
    }

    struct Row {
        let box: CALayer
        let text: CATextLayer?
        let dots: LyricDots?
        let element: LyricsPaneRow
    }

    struct Spot {
        let centre: CGFloat
        let scale: CGFloat
        let opacity: Float
    }

    static let pitch: CGFloat = 48
    static let anchor: CGFloat = 150
    static let fontSize: CGFloat = 23
    static let fades = (near: 0.55, middle: 0.32, far: 0.18, edge: 0.1)
    static let falloff = [1, fades.near, fades.middle, fades.far, fades.edge].map(Float.init)
    static let shrink: CGFloat = 0.05
    static let smallest: CGFloat = 0.82
    static let followSeconds = 3.0
    static let seekHint = "Play from this line"
    static let gapLabel = "Instrumental break"
    static let half: CGFloat = 0.5
    static let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    static let textHeight = (font.ascender - font.descender + font.leading).rounded(.up)
    private static let currentLabel = "Current line"
    private static let listLabel = "Lines"
    private static let scrollSeconds = 0.6
    private static let fadeSeconds = 0.3
    private static let curveStart = (x: 0.2, y: 0.8)
    private static let curveEnd = (x: 0.2, y: 1.0)
    private static let curve = CAMediaTimingFunction(
        controlPoints: Float(curveStart.x), Float(curveStart.y), Float(curveEnd.x),
        Float(curveEnd.y))
    private static let fadeStops = (top: 0.12, bottom: 0.84)
    private static let fallbackScale: CGFloat = 2

    var onSeek: ((Int) -> Void)?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private(set) var lines: [String] = []
    private(set) var mode = Mode.synced
    private(set) var current: Int?
    var browsed: Int?
    var offset: CGFloat = 0
    var scrolled: CGFloat = 0
    var resume: Task<Void, Never>?
    private(set) var rows: [Row] = []
    let now = NSAccessibilityElement()
    private let fill = CATextLayer()
    private let wipe = WipeMask()
    private let fade = CAGradientLayer()
    private var settled = false

    override var isFlipped: Bool {
        true
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    private var inset: CGFloat {
        bounds.height * Self.fadeStops.top
    }

    var focus: Int? {
        mode == .synced ? browsed ?? current : nil
    }

    init() {
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
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        setAccessibilityLabel(Self.listLabel)
        now.setAccessibilityRole(.staticText)
        now.setAccessibilityLabel(Self.currentLabel)
        now.setAccessibilityParent(self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly { fade.frame = bounds }
        offset = clamped(offset)
        place(animated: false)
    }

    override func updateLayer() {
        paint()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let line = line(at: convert(event.locationInWindow, from: nil)) else { return }
        onSeek?(line)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : Self.pitch)
        switch mode {
        case .plain:
            offset = clamped(offset - delta)
            place(animated: false)

        case .synced:
            scrolled += delta
            let steps = Int(scrolled / Self.pitch)
            guard steps != 0 else { return }
            scrolled -= CGFloat(steps) * Self.pitch
            browse(by: -steps)
        }
    }

    func line(at point: NSPoint) -> Int? {
        guard mode == .synced, bounds.contains(point) else { return nil }
        return rows.indices.first { abs(point.y - spot(of: $0).centre) <= Self.pitch * Self.half }
    }

    func show(_ verse: WidgetGrid.Verse) {
        let synced = verse.status == .synced
        let next = synced ? Mode.synced : .plain
        let changed = verse.lines != lines || next != mode
        if changed {
            lines = verse.lines
            mode = next
            rebuild()
        }
        let line = synced ? verse.current.flatMap { lines.indices.contains($0) ? $0 : nil } : nil
        let moved = changed || line != current
        current = line
        if moved {
            attachFill()
            now.setAccessibilityValue(line.map { lines[$0].isEmpty ? Self.gapLabel : lines[$0] })
        }
        place(animated: moved && settled)
        settled = true
        sing(verse, restart: moved)
    }

    func spot(of index: Int) -> Spot {
        guard let focus else {
            let top = inset + Self.pitch * Self.half + CGFloat(index) * Self.pitch - offset
            return Spot(centre: top, scale: 1, opacity: 1)
        }
        let distance = abs(index - focus)
        return Spot(
            centre: Self.anchor + CGFloat(index - focus) * Self.pitch,
            scale: distance == 0 ? 1 : max(Self.smallest, 1 - CGFloat(distance) * Self.shrink),
            opacity: Self.falloff[min(distance, Self.falloff.count - 1)])
    }

    func clamped(_ value: CGFloat) -> CGFloat {
        let end = inset + CGFloat(rows.count) * Self.pitch
        return max(0, min(value, end - bounds.height * Self.fadeStops.bottom))
    }

    func place(animated: Bool) {
        let still = reducesMotion()
        CATransaction.begin()
        if animated, !still {
            CATransaction.setAnimationDuration(Self.scrollSeconds)
            CATransaction.setAnimationTimingFunction(Self.curve)
        } else {
            CATransaction.setDisableActions(true)
        }
        if animated, still {
            let crossFade = CATransition()
            crossFade.duration = Self.fadeSeconds
            layer?.add(crossFade, forKey: "fade")
        }
        for (index, row) in rows.enumerated() {
            lay(row, at: spot(of: index))
        }
        CATransaction.commit()
        fitFill()
        paint()
    }

    private func rebuild() {
        resume?.cancel()
        browsed = nil
        offset = 0
        scrolled = 0
        rows.forEach { $0.box.removeFromSuperlayer() }
        rows = lines.enumerated().map { makeRow($0.offset, text: $0.element) }
        let spoken = rows.filter { $0.text != nil || $0.dots != nil }.map(\.element)
        setAccessibilityChildren([now] + spoken)
        settled = false
    }

    private func attachFill() {
        CATransaction.quietly {
            fill.removeFromSuperlayer()
            guard let current, let text = rows[current].text else { return }
            fill.string = text.string
            rows[current].box.addSublayer(fill)
        }
    }

    private func fitFill() {
        guard let current, let text = rows[current].text else { return }
        let width = NSAttributedString(string: lines[current], attributes: [.font: Self.font])
            .size().width
        CATransaction.quietly {
            fill.frame = text.frame
            wipe.fit(width: min(width, text.frame.width), height: Self.textHeight)
        }
    }

    private func sing(_ verse: WidgetGrid.Verse, restart: Bool) {
        let still = reducesMotion()
        let runs = verse.isPlaying && !still
        let progress = verse.progress
        let remaining = verse.remaining
        for (index, row) in rows.enumerated() where row.dots != nil {
            if index == current {
                row.dots?.show(progress: progress, remaining: remaining, playing: runs)
            } else if restart {
                row.dots?.show(progress: 0, remaining: nil, playing: false)
            }
        }
        guard let current, rows[current].text != nil else { return }
        wipe.run(
            from: still ? 1 : progress, remaining: still ? nil : remaining, playing: runs,
            restart: restart)
    }

    private func paint() {
        let scale = unsafe window?.backingScaleFactor ?? Self.fallbackScale
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let ink = NSColor.labelColor.cgColor
            let dim = NSColor.secondaryLabelColor.cgColor
            CATransaction.quietly {
                fill.foregroundColor = ink
                fill.contentsScale = scale
                for (index, row) in rows.enumerated() {
                    row.text?.foregroundColor = index == current ? dim : ink
                    row.text?.contentsScale = scale
                    row.dots?.colour = ink
                }
            }
        }
    }
}
