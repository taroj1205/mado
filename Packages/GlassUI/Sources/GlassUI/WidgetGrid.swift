public import AppKit

public final class WidgetGrid: NSView {
    public struct Widget: Sendable, Equatable {
        public let id: String
        public let value: String
        public let detail: String
        public let meters: [Meter]
        public let action: String
        public let spoken: String

        public init(id: String, value: String, detail: String, action: String, spoken: String) {
            self.id = id
            self.value = value
            self.detail = detail
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

    static let columns = 6
    static let rowHeight: CGFloat = 78
    static let gap: CGFloat = 8
    static let inset: CGFloat = 14
    static let top: CGFloat = 12
    private static let bottom: CGFloat = 4

    var widgets: [Widget] = [] {
        didSet {
            guard widgets != oldValue else { return }
            if widgets.count == tiles.count {
                zip(tiles, widgets).forEach { $0.show($1) }
            } else {
                rebuild()
            }
            invalidateIntrinsicContentSize()
        }
    }

    var onPress: ((Int) -> Void)?
    private(set) var tiles: [WidgetTile] = []

    override public var isFlipped: Bool { true }

    override public var isHidden: Bool {
        didSet { invalidateIntrinsicContentSize() }
    }

    override public var intrinsicContentSize: NSSize {
        let rows = (widgets.count + Self.columns - 1) / Self.columns
        guard !isHidden, rows > 0 else { return NSSize(width: NSView.noIntrinsicMetric, height: 0) }
        let height = CGFloat(rows) * Self.rowHeight + CGFloat(rows - 1) * Self.gap
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

    override public func layout() {
        super.layout()
        let area = bounds.insetBy(dx: Self.inset, dy: 0)
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        let width = (area.width - gaps) / CGFloat(Self.columns)
        for (index, tile) in tiles.enumerated() {
            let column = CGFloat(index % Self.columns)
            let row = CGFloat(index / Self.columns)
            tile.frame = NSRect(
                x: area.minX + column * (width + Self.gap),
                y: Self.top + row * (Self.rowHeight + Self.gap),
                width: width, height: Self.rowHeight)
        }
    }

    func highlight(_ index: Int?) {
        for (position, tile) in tiles.enumerated() {
            tile.selected = position == index
        }
    }

    private func rebuild() {
        tiles.forEach { $0.removeFromSuperview() }
        tiles = widgets.enumerated().map { index, widget in
            let tile = WidgetTile()
            tile.show(widget)
            tile.onPress = { [weak self] in self?.onPress?(index) }
            addSubview(tile)
            return tile
        }
        needsLayout = true
    }
}
