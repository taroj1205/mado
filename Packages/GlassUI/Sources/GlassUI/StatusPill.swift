import AppKit

final class StatusPill: NSView, NSDraggingSource {
    static let dragType = NSPasteboard.PasteboardType("com.taroj1205.mado.statuspill")
    private static let height: CGFloat = 36
    private static let radius: CGFloat = 12
    private static let leading: CGFloat = 11
    private static let trailing: CGFloat = 13
    private static let gap: CGFloat = 6
    private static let glyphGap: CGFloat = 8
    private static let glyphSize: CGFloat = 20
    private static let fontSize: CGFloat = 13
    private static let selectedAlpha = (dark: 0.17, light: 0.90)
    private static let selectedEdgeAlpha = (dark: 0.30, light: 0.14)
    static let selectedFill = NSColor(name: nil) { appearance in
        .white.withAlphaComponent(
            isDark(appearance) ? selectedAlpha.dark : selectedAlpha.light)
    }
    private static let selectedEdge = NSColor(name: nil) { appearance in
        isDark(appearance)
            ? .white.withAlphaComponent(selectedEdgeAlpha.dark)
            : .black.withAlphaComponent(selectedEdgeAlpha.light)
    }

    let icon = NSImageView()
    let glyph = NSTextField(labelWithString: "")
    let label = NSTextField(labelWithString: "")
    let glass: GlassView
    private let highlight = NSBox()
    private(set) var symbol: String?
    let slot = DashedOutline.slot(radius: StatusPill.radius)
    private var dragStart: NSEvent?
    private var hover: HoverFill?
    var onPress: (() -> Void)? {
        didSet { hover?.isHidden = onPress == nil }
    }
    var onGrab: (() -> Void)?
    var onDrop: (() -> Void)?

    var lifted = false {
        didSet {
            glass.alphaValue = lifted ? 0 : 1
            slot.isHidden = !lifted
        }
    }

    var text: String {
        label.stringValue
    }

    var selected = false {
        didSet {
            highlight.isHidden = !selected
            icon.contentTintColor = selected ? .controlAccentColor : .secondaryLabelColor
            setAccessibilitySelected(selected)
        }
    }

    init() {
        icon.symbolConfiguration = .init(pointSize: Self.fontSize, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor
        glyph.font = .systemFont(ofSize: Self.glyphSize)
        glyph.isHidden = true
        let stack = NSStackView(views: [icon, glyph, label])
        stack.spacing = Self.gap
        stack.setCustomSpacing(Self.glyphGap, after: glyph)
        glass = FloatingCapsule.make(
            stack, leading: Self.leading, trailing: Self.trailing,
            height: Self.height, radius: Self.radius)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        highlight.boxType = .custom
        highlight.cornerRadius = Self.radius
        highlight.borderWidth = 1
        highlight.fillColor = Self.selectedFill
        highlight.borderColor = Self.selectedEdge
        highlight.frame = glass.container.bounds
        highlight.autoresizingMask = [.width, .height]
        highlight.isHidden = true
        glass.container.addSubview(highlight, positioned: .below, relativeTo: stack)
        hover = HoverFill.install(in: glass.container, radius: Self.radius)
        hover?.isHidden = true
        addSubview(glass)
        slot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slot)
        NSLayoutConstraint.activate([
            slot.leadingAnchor.constraint(equalTo: leadingAnchor),
            slot.trailingAnchor.constraint(equalTo: trailingAnchor),
            slot.topAnchor.constraint(equalTo: topAnchor),
            slot.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    static func styled(_ text: String) -> NSAttributedString {
        let count = text.prefix(while: \.isNumber)
        guard !count.isEmpty, text.dropFirst(count.count).first == " " else {
            return styled(bold: "", rest: text)
        }
        return styled(bold: String(count), rest: String(text.dropFirst(count.count)))
    }

    static func styled(bold: String, rest: String) -> NSAttributedString {
        let styled = NSMutableAttributedString(
            string: bold,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        styled.append(
            NSAttributedString(
                string: rest,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        return styled
    }

    func show(_ text: String?, symbol: String?) {
        show(text.map(Self.styled), symbol: symbol)
    }

    func show(_ text: NSAttributedString, glyph: String?) {
        show(text, symbol: nil)
        self.glyph.stringValue = glyph ?? ""
        self.glyph.isHidden = glyph == nil
    }

    func show(_ text: NSAttributedString?, symbol: String?) {
        isHidden = text == nil
        self.symbol = symbol
        glyph.isHidden = true
        label.attributedStringValue = text ?? NSAttributedString()
        icon.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        icon.isHidden = icon.image == nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard onPress != nil else { return super.hitTest(point) }
        return frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        onPress != nil
    }

    override func mouseDown(with event: NSEvent) {
        if onGrab != nil, event.modifierFlags.contains(.command) {
            dragStart = event
            onGrab?()
            return
        }
        dragStart = nil
        if let onPress {
            onPress()
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with _: NSEvent) {
        guard let start = dragStart, unsafe window != nil else { return }
        dragStart = nil
        beginDrag(with: start)
    }

    override func mouseUp(with _: NSEvent) {
        if dragStart != nil {
            dragStart = nil
            onDrop?()
        }
    }

    private func beginDrag(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(identifier?.rawValue ?? "", forType: Self.dragType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let card = DragCard.make(of: self, showing: glass.contentView ?? self, radius: Self.radius)
        dragging.setDraggingFrame(card.frame, contents: card.image)
        let session = beginDraggingSession(with: [dragging], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
        lifted = true
    }

    func draggingSession(
        _: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        lifted = false
        onDrop?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }
}
