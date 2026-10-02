public import AppKit

public final class WidgetGrid: NSView {
    public struct Widget: Sendable, Equatable {
        public let id: String
        public let value: String
        public let detail: String
        public let symbol: String?
        public let meters: [Meter]
        public let action: String
        public let spoken: String

        public init(
            id: String, value: String, detail: String, action: String, spoken: String,
            symbol: String? = nil
        ) {
            self.id = id
            self.value = value
            self.detail = detail
            self.symbol = symbol
            self.action = action
            self.spoken = spoken
            meters = []
        }

        public init(id: String, meters: [Meter], action: String, spoken: String) {
            self.id = id
            self.meters = meters
            self.action = action
            self.spoken = spoken
            value = ""
            detail = ""
            symbol = nil
        }
    }

    public struct Meter: Sendable, Equatable {
        public let name: String
        public let value: String
        public let level: Double

        public init(name: String, value: String, level: Double) {
            self.name = name
            self.value = value
            self.level = level
        }
    }

    public enum Layout: Sendable {
        case grid
        case strip
        case above
        case around

        var floating: Bool { self == .above || self == .around }
    }

    static let columns = 6
    static let rowHeight: CGFloat = 78
    static let stripHeight: CGFloat = 72
    static let gap: CGFloat = 8
    static let inset: CGFloat = 14
    static let top: CGFloat = 12
    private static let bottom: CGFloat = 4
    static let floatingGap: CGFloat = 10
    static let lift: CGFloat = 16
    static let sideWidth: CGFloat = 220
    static let sideGap: CGFloat = 20
    private static let sides = 2

    var widgets: [Widget] = [] {
        didSet {
            if widgets != oldValue { update() }
        }
    }

    var tileLayout: Layout? = .grid {
        didSet {
            if tileLayout != oldValue { update(rebuilding: true) }
        }
    }

    var onPress: ((Int) -> Void)?
    private(set) var tiles: [WidgetTile] = []
    private(set) var floats: [GlassPanel] = []

    var shown: [Widget] {
        switch tileLayout {
        case .grid, .above, .around: widgets
        case .strip: Array(widgets.prefix(Self.columns))
        case nil: []
        }
    }

    private var rowHeight: CGFloat {
        tileLayout == .strip ? Self.stripHeight : Self.rowHeight
    }

    private var floating: Bool { tileLayout?.floating == true }

    var overhang: CGFloat {
        let rows = CGFloat((tiles.count + Self.columns - 1) / Self.columns)
        guard tileLayout == .above, rows > 0 else { return 0 }
        return Self.lift + rows * Self.rowHeight + (rows - 1) * Self.floatingGap
    }

    override public var isFlipped: Bool { true }

    override public var isHidden: Bool {
        didSet {
            invalidateIntrinsicContentSize()
            placeFloats()
        }
    }

    override public var intrinsicContentSize: NSSize {
        let rows = (tiles.count + Self.columns - 1) / Self.columns
        guard !isHidden, !floating, rows > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let height = CGFloat(rows) * rowHeight + CGFloat(rows - 1) * Self.gap
        return NSSize(width: NSView.noIntrinsicMetric, height: Self.top + height + Self.bottom)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Widgets")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func floatingFrames(_ layout: Layout, count: Int, beside panel: CGRect) -> [CGRect] {
        let step = rowHeight + floatingGap
        switch layout {
        case .above:
            let rows = (count + columns - 1) / columns
            let area = panel.insetBy(dx: inset, dy: 0)
            let width = (area.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
            return (0..<count).map { index in
                CGRect(
                    x: area.minX + CGFloat(index % columns) * (width + floatingGap),
                    y: panel.maxY + lift + CGFloat(rows - 1 - index / columns) * step,
                    width: width, height: rowHeight)
            }

        case .around:
            let left = (count + sides - 1) / sides
            return (0..<count).map { index in
                let leftSide = index < left
                return CGRect(
                    x: leftSide ? panel.minX - sideGap - sideWidth : panel.maxX + sideGap,
                    y: panel.maxY - rowHeight - CGFloat(leftSide ? index : index - left) * step,
                    width: sideWidth, height: rowHeight)
            }

        case .grid, .strip:
            return []
        }
    }

    private static func makeFloat(for tile: WidgetTile) -> GlassPanel {
        let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(WidgetTile.radius))
        panel.ignoresMouseEvents = false
        panel.glass.contentView = tile
        return panel
    }

    override public func layout() {
        super.layout()
        guard !floating else { return }
        let area = bounds.insetBy(dx: Self.inset, dy: 0)
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        let width = (area.width - gaps) / CGFloat(Self.columns)
        for (index, tile) in tiles.enumerated() {
            let column = CGFloat(index % Self.columns)
            let row = CGFloat(index / Self.columns)
            tile.frame = NSRect(
                x: area.minX + column * (width + Self.gap),
                y: Self.top + row * (rowHeight + Self.gap),
                width: width, height: rowHeight)
        }
    }

    func highlight(_ index: Int?) {
        for (position, tile) in tiles.enumerated() {
            tile.selected = position == index
        }
    }

    func placeFloats() {
        guard let window = unsafe window, let tileLayout, !isHidden else {
            floats.forEach { $0.orderOut(nil) }
            return
        }
        let frames = Self.floatingFrames(tileLayout, count: floats.count, beside: window.frame)
        for (float, frame) in zip(floats, frames) {
            float.setFrame(frame, display: false)
            if float.parent !== window {
                window.addChildWindow(float, ordered: .above)
            }
        }
    }

    private func update(rebuilding: Bool = false) {
        let visible = shown
        if rebuilding || visible.count != tiles.count {
            tiles.forEach { $0.removeFromSuperview() }
            floats.forEach { $0.orderOut(nil) }
            tiles = visible.indices.map { index in
                let tile = WidgetTile(floating: floating)
                tile.onPress = { [weak self] in self?.onPress?(index) }
                return tile
            }
            floats = floating ? tiles.map(Self.makeFloat) : []
            if !floating { tiles.forEach(addSubview) }
        }
        zip(tiles, visible).forEach { $0.show($1) }
        placeFloats()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}
