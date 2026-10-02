public import AppKit

public final class WidgetGrid: NSView {
    public struct Widget: Sendable, Equatable {
        static let wideSpan = 2

        public let id: String
        public let content: Content
        public let action: String
        public let spoken: String
        public let isWide: Bool

        var span: Int {
            isWide ? Self.wideSpan : 1
        }

        var track: Track? {
            if case .track(let playing) = content { playing } else { nil }
        }

        public init(
            id: String, content: Content, action: String, spoken: String, isWide: Bool = false
        ) {
            self.id = id
            self.content = content
            self.action = action
            self.spoken = spoken
            self.isWide = isWide
        }

        public init(
            id: String, value: String, detail: String, action: String, spoken: String,
            symbol: String? = nil
        ) {
            self.init(
                id: id, content: .value(value, detail: detail, symbol: symbol), action: action,
                spoken: spoken)
        }

        public init(id: String, meters: [Meter], action: String, spoken: String) {
            self.init(id: id, content: .meters(meters), action: action, spoken: spoken)
        }

        public init(id: String, track: Track, action: String, spoken: String) {
            self.init(
                id: id, content: .track(track), action: action, spoken: spoken, isWide: true)
        }
    }

    public enum Content: Sendable, Equatable {
        case value(String, detail: String, symbol: String? = nil)
        case meters([Meter])
        case track(Track)
        case loading(title: String)
        case notice(title: String, headline: String, detail: String)
        case permission(title: String, request: String, reason: String)
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
    }

    public enum Skip: Sendable {
        case previous
        case next
    }

    public struct Track: Sendable, Equatable {
        public let title: String
        public let artist: String
        public let artwork: Data?
        public let isPlaying: Bool

        public init(title: String, artist: String, artwork: Data?, isPlaying: Bool) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
            self.isPlaying = isPlaying
        }
    }

    static let columns = 6
    static let rowHeight: CGFloat = 78
    static let stripHeight: CGFloat = 72
    static let gap: CGFloat = 8
    static let inset: CGFloat = 14
    static let top: CGFloat = 12
    private static let bottom: CGFloat = 4

    var widgets: [Widget] = [] {
        didSet {
            if widgets != oldValue { update() }
        }
    }

    var tileLayout: Layout? = .grid {
        didSet {
            if tileLayout != oldValue { update() }
        }
    }

    var onPress: ((Int) -> Void)?
    var onSkip: ((Int, Skip) -> Void)?
    private(set) var tiles: [WidgetTile] = []

    var shown: [Widget] {
        switch tileLayout {
        case .grid: widgets
        case .strip: Array(widgets.prefix(Self.cells(of: widgets).count { $0.row == 0 }))
        case nil: []
        }
    }

    private var rowHeight: CGFloat {
        tileLayout == .strip ? Self.stripHeight : Self.rowHeight
    }

    override public var isFlipped: Bool { true }

    override public var isHidden: Bool {
        didSet { invalidateIntrinsicContentSize() }
    }

    override public var intrinsicContentSize: NSSize {
        let rows = Self.cells(of: shown).last.map { $0.row + 1 } ?? 0
        guard !isHidden, rows > 0 else { return NSSize(width: NSView.noIntrinsicMetric, height: 0) }
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

    private static func cells(of widgets: [Widget]) -> [(row: Int, columns: Range<Int>)] {
        var row = 0
        var column = 0
        return widgets.map { widget in
            if column + widget.span > columns {
                row += 1
                column = 0
            }
            defer { column += widget.span }
            return (row, column..<column + widget.span)
        }
    }

    override public func layout() {
        super.layout()
        let area = bounds.insetBy(dx: Self.inset, dy: 0)
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        let width = (area.width - gaps) / CGFloat(Self.columns)
        for (tile, cell) in zip(tiles, Self.cells(of: shown)) {
            tile.frame = NSRect(
                x: area.minX + CGFloat(cell.columns.lowerBound) * (width + Self.gap),
                y: Self.top + CGFloat(cell.row) * (rowHeight + Self.gap),
                width: CGFloat(cell.columns.count) * (width + Self.gap) - Self.gap,
                height: rowHeight)
        }
    }

    func highlight(_ index: Int?) {
        for (position, tile) in tiles.enumerated() {
            tile.selected = position == index
        }
    }

    private func update() {
        let visible = shown
        if visible.count != tiles.count {
            tiles.forEach { $0.removeFromSuperview() }
            tiles = visible.indices.map { index in
                let tile = WidgetTile()
                tile.onPress = { [weak self] in self?.onPress?(index) }
                tile.onSkip = { [weak self] skip in self?.onSkip?(index, skip) }
                addSubview(tile)
                return tile
            }
        }
        zip(tiles, visible).forEach { $0.show($1) }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}
