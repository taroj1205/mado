public import AppKit

public final class WidgetGrid: NSView {
    public enum Content: Sendable, Equatable {
        case value(String, detail: String, symbol: String? = nil, span: Span? = nil)
        case meters([Meter])
        case track(Track)
        case month(Month)
        case event(title: String, Event)
        case loading(title: String)
        case notice(title: String, headline: String, detail: String)
        case permission(title: String, request: String, reason: String)
        case unavailable(title: String, summary: String)
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

    nonisolated static let columns = 6
    nonisolated static let widest = 3
    static let dragType = NSPasteboard.PasteboardType("com.taroj1205.mado.widget")
    static let rowHeight: CGFloat = 78
    static let stripHeight: CGFloat = 72
    static let gap: CGFloat = 8
    static let inset: CGFloat = 14
    static let top: CGFloat = 12
    private static let bottom: CGFloat = 4
    private static let dockInset: CGFloat = 6
    private static let dockEdge: CGFloat = 1.5
    private static let captionSize: CGFloat = 10.5
    private static let captionKern: CGFloat = 0.9
    private static let captionInset: CGFloat = 2
    private static let half: CGFloat = 0.5
    static let lift: CGFloat = 16
    nonisolated static let railColumns = (narrowest: 2, widest: 3)
    static let sideGap: CGFloat = 20
    nonisolated static let sides = 2

    var widgets: [Widget] {
        get {
            supplied.map { widget in
                var sized = widget
                sized.resized = (trial[widget.id] ?? sizes[widget.id]).map { size in
                    limited(size, for: widget)
                }
                return sized
            }
        }
        set { supplied = newValue }
    }

    var supplied: [Widget] = [] {
        didSet {
            if supplied != oldValue { update() }
        }
    }

    var sizes: [String: Size] = [:] {
        didSet {
            if sizes != oldValue { update() }
        }
    }

    var trial: [String: Size] = [:] {
        didSet {
            if trial != oldValue { update() }
        }
    }

    var tileLayout: Layout? = .grid {
        didSet {
            if tileLayout != oldValue { update(rebuilding: true) }
        }
    }

    var spots: [String: Spot] = [:] {
        didSet {
            if spots != oldValue { update() }
        }
    }

    var editing = false {
        didSet {
            guard editing != oldValue else { return }
            dragged = nil
            order = []
            incoming = nil
            update(rebuilding: true)
        }
    }

    var picked: [String] = []

    var order: [String] = [] {
        didSet {
            if order != oldValue { update() }
        }
    }

    var incoming: Widget? {
        didSet {
            if incoming != oldValue { update() }
        }
    }

    var dragged: String? {
        didSet {
            if dragged != oldValue { update() }
        }
    }

    var moving: Spot? {
        didSet {
            if moving != oldValue { update() }
        }
    }

    var refused: Spot? {
        didSet {
            if refused != oldValue { placeFloats() }
        }
    }

    var carrying = false
    var source: WidgetTile?
    let rails = WidgetRails()
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var onPress: ((Int) -> Void)?
    var onOpen: ((Int) -> Void)?
    var opensOnSingleClick = false {
        didSet { tiles.forEach { $0.opensOnSingleClick = opensOnSingleClick } }
    }
    var onExtend: ((Int) -> Void)?
    var onSkip: ((Int, Skip) -> Void)?
    var onDay: ((String) -> Void)?
    var onPage: ((Int, Page) -> Void)?
    var onRemove: ((Int) -> Void)?
    var onResize: ((Int, WidgetTile.Resize) -> Void)?
    var onDrag: ((String?, NSPoint, Any?) -> NSDragOperation)?
    var onDrop: ((String?) -> Bool)?
    var onDragEnd: (() -> Void)?
    private(set) var tiles: [WidgetTile] = []
    private(set) var floats: [GlassPanel] = []
    let dock = DashedOutline(
        colour: WidgetRailsView.dock, width: dockEdge, fill: .clear, radius: WidgetTile.radius)
    let dockCaption = NSTextField(labelWithString: "IN THE PANEL · DROP OR CLICK A WIDGET BELOW")

    var rowHeight: CGFloat {
        tileLayout == .strip ? Self.stripHeight : Self.rowHeight
    }

    private var spareRows: Int {
        tileLayout == .grid ? min(Self.rowCount(of: panelCells) + 1, Self.maxPanelRows) : 1
    }

    override public var isFlipped: Bool { true }

    override public var isHidden: Bool {
        didSet {
            invalidateIntrinsicContentSize()
            placeFloats()
        }
    }

    override public var intrinsicContentSize: NSSize {
        let rows = max(Self.rowCount(of: panelCells), editing ? spareRows : 0)
        guard !isHidden, rows > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let height = Self.extent(of: rows, unit: rowHeight, gap: Self.gap)
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
        dock.isHidden = true
        dockCaption.attributedStringValue = NSAttributedString(
            string: dockCaption.stringValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.captionSize, weight: .semibold),
                .kern: Self.captionKern, .foregroundColor: NSColor.tertiaryLabelColor,
            ])
        dockCaption.isHidden = true
        addSubview(dock)
        addSubview(dockCaption)
        rails.board.onDrag = { [weak self] id, point, source in
            self?.onDrag?(id, point, source) ?? []
        }
        rails.board.onDrop = { [weak self] id in self?.onDrop?(id) ?? false }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func layout() {
        super.layout()
        let frames = frames(of: panelCells)
        for (index, (tile, frame)) in zip(tiles.filter { !$0.floating }, frames).enumerated() {
            place(tile, in: frame, tilt: tilt(at: index))
        }
        dock.frame = bounds.insetBy(dx: Self.dockInset, dy: 0)
        dock.frame.origin.y = Self.dockInset
        dock.frame.size.height = bounds.height - Self.dockInset - Self.bottom
        let caption = dockCaption.fittingSize
        dockCaption.frame = NSRect(
            x: Self.inset + Self.captionInset, y: dock.frame.midY - caption.height * Self.half,
            width: caption.width, height: caption.height)
    }

    private func update(rebuilding: Bool = false) {
        let visible = shown
        let floating = visible.map { spot(of: $0).side != .panel }
        if rebuilding || floating != tiles.map(\.floating) {
            tiles.forEach { $0.removeFromSuperview() }
            floats.forEach { $0.orderOut(nil) }
            tiles = zip(visible.indices, floating).map(makeTile)
            floats = tiles.filter(\.floating).map(Self.makeFloat)
            tiles.filter { !$0.floating }.forEach(addSubview)
        }
        for (tile, widget) in zip(tiles, visible) {
            tile.compact = tileLayout == .strip && !tile.floating
            tile.show(widget)
            tile.lifted = widget.id == dragged
            tile.resizes = resizes(of: widget)
        }
        dock.isHidden = !editing
        dockCaption.isHidden = !editing || !inPanel.isEmpty
        placeFloats()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}
