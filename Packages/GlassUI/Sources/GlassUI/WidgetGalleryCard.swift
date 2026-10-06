import AppKit

final class WidgetGalleryCard: NSView, NSDraggingSource {
    final class Badge: NSView {
        private static let symbolSize: CGFloat = 10
        private static let shadowBlur: CGFloat = 6
        private static let shadowDrop: CGFloat = 2
        private static let shadowAlpha: CGFloat = 0.3
        private static let half: CGFloat = 0.5

        var isAdded = false {
            didSet {
                if isAdded != oldValue { needsDisplay = true }
            }
        }

        override init(frame: NSRect) {
            super.init(frame: frame)
            let shade = NSShadow()
            shade.shadowBlurRadius = Self.shadowBlur
            shade.shadowOffset = NSSize(width: 0, height: -Self.shadowDrop)
            shade.shadowColor = .black.withAlphaComponent(Self.shadowAlpha)
            shadow = shade
            setAccessibilityElement(false)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        override func draw(_: NSRect) {
            (isAdded ? NSColor.systemGreen : .controlAccentColor).setFill()
            NSBezierPath(ovalIn: bounds).fill()
            let configuration = NSImage.SymbolConfiguration(
                pointSize: Self.symbolSize, weight: .heavy
            )
            .applying(.init(paletteColors: [.white]))
            guard
                let symbol = NSImage(
                    systemSymbolName: isAdded ? "checkmark" : "plus", accessibilityDescription: nil
                )?
                .withSymbolConfiguration(configuration)
            else { return }
            symbol.draw(
                in: NSRect(
                    x: bounds.midX - symbol.size.width * Self.half,
                    y: bounds.midY - symbol.size.height * Self.half, width: symbol.size.width,
                    height: symbol.size.height))
        }
    }

    static let labelHeight: CGFloat = 15
    static let labelGap: CGFloat = 6
    private static let nameSize: CGFloat = 12
    private static let noteSize: CGFloat = 11.5
    private static let nameGap: CGFloat = 6
    private static let labelInset: CGFloat = 4
    private static let badgeSize: CGFloat = 22
    private static let badgeOverhang: CGFloat = 7
    private static let addedAlpha: CGFloat = 0.55

    let card: WidgetGallery.Card
    let tile = WidgetTile(floating: false)
    let badge = Badge()
    let name = NSTextField(labelWithString: "")
    let note = NSTextField(labelWithString: "")
    private var dragStart: NSEvent?
    var onPick: (() -> Void)?
    var onDragEnd: (() -> Void)?

    private(set) var widget: WidgetGrid.Widget

    var spot: WidgetGrid.Spot? {
        didSet { showSpot() }
    }

    init(_ card: WidgetGallery.Card, showing widget: WidgetGrid.Widget) {
        self.card = card
        self.widget = widget
        super.init(frame: .zero)
        tile.setAccessibilityElement(false)
        name.stringValue = card.name
        name.font = .systemFont(ofSize: Self.nameSize, weight: .semibold)
        note.font = .systemFont(ofSize: Self.noteSize)
        note.lineBreakMode = .byTruncatingTail
        note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let labels = NSStackView(views: [name, note])
        labels.spacing = Self.nameGap
        labels.alignment = .firstBaseline
        labels.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.labelInset, bottom: 0, right: Self.labelInset)
        labels.translatesAutoresizingMaskIntoConstraints = false
        tile.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        [tile, labels, badge].forEach(addSubview)
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: topAnchor),
            tile.leadingAnchor.constraint(equalTo: leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: trailingAnchor),
            tile.heightAnchor.constraint(
                equalToConstant: WidgetGrid.extent(
                    of: widget.size.rows, unit: WidgetGrid.rowHeight, gap: WidgetGrid.gap)),
            labels.topAnchor.constraint(equalTo: tile.bottomAnchor, constant: Self.labelGap),
            labels.leadingAnchor.constraint(equalTo: leadingAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            badge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -Self.badgeOverhang),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: -Self.badgeOverhang),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        tile.show(widget)
        showSpot()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ widget: WidgetGrid.Widget) {
        guard widget != self.widget else { return }
        self.widget = widget
        tile.show(widget)
    }

    private func showSpot() {
        tile.alphaValue = spot == nil ? 1 : Self.addedAlpha
        badge.isAdded = spot != nil
        note.stringValue = spot?.title ?? card.summary
        note.textColor = spot == nil ? .secondaryLabelColor : .systemGreen
        setAccessibilityLabel(
            spot.map { "\(card.name), added, \($0.title). Show it" } ?? "Add \(card.name)")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        guard spot == nil else { return }
        let item = NSPasteboardItem()
        item.setString(card.id, forType: WidgetGrid.dragType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(tile.frame, contents: tile.snapshot())
        beginDraggingSession(with: [dragging], event: event, source: self)
    }

    override func mouseUp(with _: NSEvent) {
        if dragStart != nil {
            dragStart = nil
            onPick?()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onPick?()
        return true
    }

    func draggingSession(
        _: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .copy : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        onDragEnd?()
    }
}
