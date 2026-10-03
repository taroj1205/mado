public import AppKit

public final class WidgetGrid: NSView {
    public struct Widget: Sendable, Equatable {
        static let wideSpan = 2

        public let id: String
        public let name: String
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

        var isUnavailable: Bool {
            if case .unavailable = content { true } else { false }
        }

        public init(
            id: String, name: String, content: Content, action: String, spoken: String,
            isWide: Bool = false
        ) {
            self.id = id
            self.name = name
            self.content = content
            self.action = action
            self.spoken = spoken
            self.isWide = isWide
        }

        public init(
            id: String, name: String, value: String, detail: String, action: String,
            spoken: String, symbol: String? = nil
        ) {
            self.init(
                id: id, name: name, content: .value(value, detail: detail, symbol: symbol),
                action: action, spoken: spoken)
        }

        public init(id: String, name: String, meters: [Meter], action: String, spoken: String) {
            self.init(
                id: id, name: name, content: .meters(meters), action: action, spoken: spoken)
        }

        public init(id: String, name: String, track: Track, action: String, spoken: String) {
            self.init(
                id: id, name: name, content: .track(track), action: action, spoken: spoken,
                isWide: true)
        }
    }

    public enum Content: Sendable, Equatable {
        case value(String, detail: String, symbol: String? = nil)
        case meters([Meter])
        case track(Track)
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
        case above
        case around

        var floating: Bool { self == .above || self == .around }
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
    static let dragType = NSPasteboard.PasteboardType("com.taroj1205.mado.widget")
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
    static let sides = 2

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

    var editing = false {
        didSet {
            guard editing != oldValue else { return }
            dragged = nil
            order = []
            incoming = nil
            update(rebuilding: true)
        }
    }

    var order: [String] = [] {
        didSet {
            if order != oldValue { update() }
        }
    }

    var incoming: Int? {
        didSet {
            if incoming != oldValue { update() }
        }
    }

    var dragged: String?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var onPress: ((Int) -> Void)?
    var onSkip: ((Int, Skip) -> Void)?
    var onRemove: ((Int) -> Void)?
    private(set) var tiles: [WidgetTile] = []
    private(set) var floats: [GlassPanel] = []
    let dropFrame = WidgetDropFrame()

    var shown: [Widget] {
        let listed = editing ? widgets : widgets.filter { !$0.isUnavailable }
        let arranged =
            order.isEmpty ? listed : order.compactMap { id in listed.first { $0.id == id } }
        switch layoutInUse {
        case .grid, .above, .around: return arranged
        case .strip: return Array(arranged.prefix(Self.cells(of: arranged).count { $0.row == 0 }))
        case nil: return []
        }
    }

    private var layoutInUse: Layout? { editing ? .grid : tileLayout }

    var rowHeight: CGFloat {
        layoutInUse == .strip ? Self.stripHeight : Self.rowHeight
    }

    private var floating: Bool { layoutInUse?.floating == true }

    private var spans: [Int] { shown.map(\.span) + (incoming.map { [$0] } ?? []) }

    var overhang: CGFloat {
        let rows = CGFloat(Self.cells(of: shown).last.map { $0.row + 1 } ?? 0)
        guard layoutInUse == .above, rows > 0 else { return 0 }
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
        let rows = Self.cells(spanning: spans).last.map { $0.row + 1 } ?? 0
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
        dropFrame.isHidden = true
        addSubview(dropFrame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
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
        let frames = frames(spanning: spans)
        for (index, (tile, frame)) in zip(tiles, frames).enumerated() {
            place(tile, in: frame, tilt: tilt(at: index))
        }
        if incoming != nil, let last = frames.last {
            dropFrame.frame = last
        }
    }

    func highlight(_ index: Int?) {
        for (position, tile) in tiles.enumerated() {
            tile.selected = position == index
        }
    }

    func placeFloats() {
        guard let window = unsafe window, let layoutInUse, !isHidden else {
            floats.forEach { $0.orderOut(nil) }
            return
        }
        let frames = Self.floatingFrames(layoutInUse, for: shown, beside: window.frame)
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
                tile.editing = editing
                tile.onPress = { [weak self] in self?.onPress?(index) }
                tile.onSkip = { [weak self] skip in self?.onSkip?(index, skip) }
                tile.onRemove = { [weak self] in self?.onRemove?(index) }
                return tile
            }
            floats = floating ? tiles.map(Self.makeFloat) : []
            if !floating { tiles.forEach(addSubview) }
        }
        for (tile, widget) in zip(tiles, visible) {
            tile.show(widget)
            tile.lifted = widget.id == dragged
        }
        dropFrame.isHidden = incoming == nil
        placeFloats()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}
