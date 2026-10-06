import AppKit

final class LyricsSpotLayer: CALayer {
    enum State {
        case hover
        case idle
        case selected
    }

    private enum Kind {
        case card
        case island
        case pill
        case type
        case wave

        init(_ spot: LyricsSpot) {
            self =
                switch spot {
                case .corner: .card
                case .island: .island
                case .menus: .pill
                case .menuBar: .wave
                case .desktop, .dock: .type
                }
        }
    }

    private static let cardRadius: CGFloat = 9
    private static let typeRadius: CGFloat = 6
    private static let half: CGFloat = 0.5
    private static let pad: CGFloat = 6
    private static let gap: CGFloat = 5
    private static let strong: CGFloat = 4
    private static let soft: CGFloat = 3
    private static let coverShare: CGFloat = 0.42
    private static let shortRow: CGFloat = 0.5
    private static let longRow: CGFloat = 0.88
    private static let midRow: CGFloat = 0.64
    private static let waveWidth: CGFloat = 1.6
    private static let waveShort: CGFloat = 0.3
    private static let waveTall: CGFloat = 0.62
    private static let waveMid: CGFloat = 0.45
    private static let brightAlpha = 0.92
    private static let faintAlpha = 0.33
    private static let idleFill = 0.1
    private static let hoverFill = 0.22
    private static let idleStroke = 0.45
    private static let hoverStroke = 0.9
    private static let selectedStroke = 0.95
    private static let idleMark = 0.55
    private static let hoverMark = 0.85
    private static let glowOpacity: Float = 0.75
    private static let glowRadius: CGFloat = 9

    private let outline = CAShapeLayer()
    private var bright: [CALayer] = []
    private var faint: [CALayer] = []

    init(_ spot: LyricsSpot, frame: CGRect) {
        super.init()
        self.frame = frame
        isGeometryFlipped = true
        let box = CGRect(origin: .zero, size: frame.size)
        let kind = Kind(spot)
        let radius =
            switch kind {
            case .card: Self.cardRadius
            case .type: Self.typeRadius
            case .island, .pill, .wave: frame.height * Self.half
            }
        let path = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius).cgPath
        cornerRadius = radius
        cornerCurve = .continuous
        shadowPath = path
        shadowOffset = .zero
        shadowRadius = Self.glowRadius
        outline.path = path
        outline.fillColor = nil
        outline.lineWidth = 1
        addSublayer(outline)
        build(kind, in: box)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func apply(_ state: State, accent: CGColor) {
        let fill: Double
        let stroke: Double
        let mark: Double
        switch state {
        case .idle: (fill, stroke, mark) = (Self.idleFill, Self.idleStroke, Self.idleMark)
        case .hover: (fill, stroke, mark) = (Self.hoverFill, Self.hoverStroke, 1)
        case .selected: (fill, stroke, mark) = (0, Self.selectedStroke, 1)
        }
        let white = NSColor.white
        backgroundColor = state == .selected ? accent : white.withAlphaComponent(fill).cgColor
        shadowColor = accent
        shadowOpacity = state == .selected ? Self.glowOpacity : 0
        outline.strokeColor = white.withAlphaComponent(stroke).cgColor
        for layer in bright {
            layer.backgroundColor = white.withAlphaComponent(mark * Self.brightAlpha).cgColor
        }
        for layer in faint {
            layer.backgroundColor = white.withAlphaComponent(mark * Self.faintAlpha).cgColor
        }
    }

    private func build(_ kind: Kind, in box: CGRect) {
        switch kind {
        case .card: buildCard(in: box)
        case .island: buildIsland(in: box)
        case .pill: buildPill(in: box)
        case .type: buildType(in: box)
        case .wave: buildWave(in: box)
        }
    }

    private func buildCard(in box: CGRect) {
        let side = box.height * Self.coverShare
        let cover = CGRect(x: Self.pad, y: Self.pad, width: side, height: side)
        add(cover, round: true, strong: true)
        let left = cover.maxX + Self.gap
        let room = box.width - left - Self.pad
        let top = Self.pad + Self.soft
        add(CGRect(x: left, y: top, width: room, height: Self.strong), round: true, strong: true)
        add(
            CGRect(
                x: left, y: top + Self.strong + Self.gap, width: room * Self.midRow,
                height: Self.soft), round: true, strong: false)
        add(
            CGRect(
                x: Self.pad, y: cover.maxY + Self.gap, width: box.width - Self.pad - Self.pad,
                height: Self.soft), round: true, strong: false)
    }

    private func buildIsland(in box: CGRect) {
        let side = box.height - Self.pad
        let cover = CGRect(
            x: Self.pad, y: (box.height - side) * Self.half, width: side, height: side)
        add(cover, round: true, strong: true)
        let left = cover.maxX + Self.gap
        add(
            CGRect(
                x: left, y: (box.height - Self.strong) * Self.half,
                width: box.width - left - Self.pad, height: Self.strong), round: true, strong: true)
    }

    private func buildPill(in box: CGRect) {
        let thick = box.height - Self.gap
        add(
            CGRect(
                x: Self.pad, y: (box.height - thick) * Self.half,
                width: box.width - Self.pad - Self.pad, height: thick), round: true, strong: true)
    }

    private func buildWave(in box: CGRect) {
        var left = Self.pad
        for share in [Self.waveShort, Self.waveTall, Self.waveMid] {
            let tall = box.height * share
            add(
                CGRect(
                    x: left, y: (box.height - tall) * Self.half, width: Self.waveWidth,
                    height: tall), round: true, strong: true)
            left += Self.waveWidth + Self.waveWidth
        }
        left += Self.gap
        let thick = box.height - Self.gap - Self.gap
        add(
            CGRect(
                x: left, y: (box.height - thick) * Self.half, width: box.width - left - Self.pad,
                height: thick), round: true, strong: false)
    }

    private func buildType(in box: CGRect) {
        let width = box.width - Self.pad - Self.pad
        let stack = Self.soft + Self.strong + Self.soft + Self.gap + Self.gap
        var top = (box.height - stack) * Self.half
        let rows: [(share: CGFloat, thick: CGFloat)] = [
            (Self.shortRow, Self.soft), (Self.longRow, Self.strong), (Self.midRow, Self.soft),
        ]
        for row in rows {
            add(
                CGRect(x: Self.pad, y: top, width: width * row.share, height: row.thick),
                round: true, strong: row.thick == Self.strong)
            top += row.thick + Self.gap
        }
    }

    private func add(_ rect: CGRect, round: Bool, strong: Bool) {
        let mark = CALayer()
        mark.frame = rect
        mark.cornerRadius = round ? min(rect.width, rect.height) * Self.half : 0
        if strong { bright.append(mark) } else { faint.append(mark) }
        addSublayer(mark)
    }
}
