public import AppKit

@MainActor
public final class SwitcherOverlay {
    public struct Card {
        public let title: String
        public let app: String
        public let icon: NSImage?
        public let thumbnail: CGImage?

        public init(title: String, app: String, icon: NSImage?, thumbnail: CGImage?) {
            self.title = title
            self.app = app
            self.icon = icon
            self.thumbnail = thumbnail
        }
    }

    private final class Grid: NSView {
        override var isFlipped: Bool { true }
    }

    private static let radius: CGFloat = 28
    private static let margin: CGFloat = 70
    private static let hintGap: CGFloat = 28
    private static let hintHeight: CGFloat = 34
    private static let hintInset: CGFloat = 16
    private static let hintSpacing: CGFloat = 14
    private static let hintSize: CGFloat = 12.5
    private static let half: CGFloat = 0.5

    public static var thumbnailSize: CGSize { SwitcherCard.thumbnailSize }

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))
    let hint = OverlayPanel()
    let count = NSTextField(labelWithString: "")
    private let grid = Grid()
    private(set) var cards: [SwitcherCard] = []
    private var layout = SwitcherGrid(count: 0, card: SwitcherCard.size, fitting: .zero)
    private var firstRow = 0
    private var shownAt: CGPoint?
    var pointer = { NSEvent.mouseLocation }
    public var onPick: ((Int) -> Void)?
    public var onHover: ((Int) -> Void)?

    public var isVisible: Bool { panel.isVisible }

    public init() {
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        hint.animationBehavior = .none
        panel.glass.contentView = grid
        let border = GlassBorder(radius: Self.radius)
        border.frame = panel.glass.container.bounds
        border.autoresizingMask = [.width, .height]
        panel.glass.container.addSubview(border)
        grid.setAccessibilityElement(true)
        grid.setAccessibilityRole(.list)
        grid.setAccessibilityLabel("Window switcher")
        makeHint()
    }

    private static func styled(_ parts: [(String, bold: Bool)]) -> NSAttributedString {
        let text = NSMutableAttributedString()
        for (part, bold) in parts {
            text.append(
                NSAttributedString(
                    string: part,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: hintSize, weight: bold ? .bold : .regular),
                        .foregroundColor: bold ? NSColor.labelColor : .secondaryLabelColor,
                    ]))
        }
        return text
    }

    private func makeHint() {
        let move = NSTextField(
            labelWithAttributedString: Self.styled([
                ("Hold ", false), ("⌥", true), (", press ", false), ("Tab", true),
                (" to move", false),
            ]))
        let keys = NSTextField(
            labelWithAttributedString: Self.styled([("Q quits · W closes · H hides", false)]))
        for label in [move, keys, count] {
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let stack = NSStackView(views: [move, keys, count])
        stack.spacing = Self.hintSpacing
        let glass = FloatingCapsule.make(
            stack, leading: Self.hintInset, trailing: Self.hintInset, height: Self.hintHeight,
            radius: Self.hintHeight * Self.half)
        let content = NSView()
        content.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            glass.topAnchor.constraint(equalTo: content.topAnchor),
            glass.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        hint.contentView = content
        hint.hasShadow = true
    }

    public func show(_ cards: [Card], selected: Int, on screen: NSScreen) {
        shownAt = pointer()
        self.cards.forEach { $0.removeFromSuperview() }
        self.cards = cards.enumerated().map { index, card in
            let view = SwitcherCard(card)
            view.onPress = { [weak self] in self?.onPick?(index) }
            view.onHover = { [weak self] in self?.hovered(index) }
            grid.addSubview(view)
            return view
        }
        let room = screen.visibleFrame.insetBy(dx: Self.margin, dy: Self.margin)
        let limit = CGSize(
            width: room.width, height: room.height - Self.hintGap - Self.hintHeight)
        layout = SwitcherGrid(count: cards.count, card: SwitcherCard.size, fitting: limit)
        firstRow = 0
        place(on: screen)
        select(selected)
        panel.orderFrontRegardless()
        hint.orderFrontRegardless()
    }

    public func select(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        firstRow = layout.firstRow(showing: index, from: firstRow)
        for (offset, card) in cards.enumerated() {
            card.selected = offset == index
            let origin = layout.origin(of: offset, firstRow: firstRow)
            card.isHidden = origin == nil
            card.setFrameOrigin(origin ?? .zero)
        }
        let noun = cards.count == 1 ? "window" : "windows"
        count.attributedStringValue = Self.styled([
            ("\(index + 1) of \(cards.count) \(noun)", false)
        ])
        layoutHint()
    }

    public func index(_ index: Int, movedBy rowCount: Int) -> Int {
        layout.index(index, movedBy: rowCount, count: cards.count)
    }

    private func hovered(_ index: Int) {
        guard pointer() != shownAt else { return }
        onHover?(index)
    }

    public func showThumbnail(_ image: CGImage, at index: Int) {
        guard cards.indices.contains(index) else { return }
        cards[index].thumbnail.image = image
    }

    public func hide() {
        for window in [hint, panel] {
            window.orderOut(nil)
        }
    }

    private func place(on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = layout.size
        let group = size.height + Self.hintGap + Self.hintHeight
        panel.setFrame(
            CGRect(
                x: (visible.midX - size.width * Self.half).rounded(),
                y: (visible.midY + group * Self.half - size.height).rounded(),
                width: size.width, height: size.height),
            display: false)
    }

    private func layoutHint() {
        let width = hint.contentView?.fittingSize.width ?? 0
        hint.setFrame(
            CGRect(
                x: (panel.frame.midX - width * Self.half).rounded(),
                y: panel.frame.minY - Self.hintGap - Self.hintHeight, width: width,
                height: Self.hintHeight),
            display: true)
    }
}
