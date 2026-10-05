public import AppKit

public final class WidgetGallery: NSView {
    final class Board: NSView {
        override var isFlipped: Bool { true }
    }

    private static let top: CGFloat = 14
    private static let titleLeading: CGFloat = 2
    private static let titleGap: CGFloat = 14
    private static let chipGap: CGFloat = 6
    private static let headerHeight: CGFloat = 24
    private static let headerGap: CGFloat = 10
    private static let gridTop: CGFloat = 8
    private static let rowGap: CGFloat = 14
    static let bottomRoom: CGFloat = 74
    private static let titleSize: CGFloat = 13
    private static let countSize: CGFloat = 12
    private static let chipSize: CGFloat = 12
    private static let emptyTop: CGFloat = 34
    private static let emptySymbolSize: CGFloat = 20
    private static let emptySize: CGFloat = 13
    private static let emptyGap: CGFloat = 8
    private static let cardHeight =
        WidgetGrid.rowHeight + WidgetGalleryCard.labelGap + WidgetGalleryCard.labelHeight

    let title = NSTextField(labelWithString: "Add widgets")
    let chips = ([nil] + Group.allCases).map { group in
        let chip = ChipButton(
            font: .systemFont(ofSize: WidgetGallery.chipSize, weight: .medium),
            height: WidgetGallery.headerHeight, symbol: nil)
        chip.title = group?.title ?? "All"
        return chip
    }
    let count = NSTextField(labelWithString: "")
    let scroll = NSScrollView()
    let board = Board()
    let empty = NSStackView()
    let emptySymbol = NSImageView()
    let emptyText = NSTextField(labelWithString: "")
    private(set) var cards: [WidgetGalleryCard] = []
    var onPick: ((String) -> Void)?
    var onDragEnd: (() -> Void)?

    var catalogue: [Card] = [] {
        didSet {
            if catalogue != oldValue { makeCards() }
        }
    }

    var previews: [WidgetGrid.Widget] = [] {
        didSet {
            for card in cards {
                card.show(preview(of: card.card))
            }
            needsLayout = true
        }
    }

    var placed: [String: WidgetGrid.Spot] = [:] {
        didSet { showPlaced() }
    }

    var query = "" {
        didSet { needsLayout = true }
    }

    private(set) var group: Group? {
        didSet {
            paintChips()
            needsLayout = true
        }
    }

    var shown: [WidgetGalleryCard] {
        let words = query.trimmingCharacters(in: .whitespaces)
        return cards.filter { card in
            (group == nil || card.card.group == group) && card.card.matches(words)
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        count.font = .systemFont(ofSize: Self.countSize)
        count.textColor = .secondaryLabelColor
        for (chip, choice) in zip(chips, [nil] + Group.allCases) {
            chip.onPress = { [weak self] in self?.group = choice }
        }
        let header = NSStackView(views: [title] + chips + [NSView(), count])
        header.spacing = Self.chipGap
        header.setCustomSpacing(Self.titleGap, after: title)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = board
        setUpEmpty()
        for view in [header, scroll, empty] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: Self.top),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            header.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: WidgetGrid.inset + Self.titleLeading),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WidgetGrid.inset),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Self.headerGap),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            empty.topAnchor.constraint(equalTo: scroll.topAnchor, constant: Self.emptyTop),
            empty.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title.stringValue)
        paintChips()
        showPlaced()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func layout() {
        super.layout()
        arrange()
    }

    private func setUpEmpty() {
        emptySymbol.symbolConfiguration = .init(pointSize: Self.emptySymbolSize, weight: .light)
        emptySymbol.contentTintColor = .tertiaryLabelColor
        emptyText.font = .systemFont(ofSize: Self.emptySize)
        emptyText.textColor = .secondaryLabelColor
        empty.setViews([emptySymbol, emptyText], in: .center)
        empty.orientation = .vertical
        empty.spacing = Self.emptyGap
    }

    private func preview(of card: Card) -> WidgetGrid.Widget {
        previews.first { $0.id == card.id } ?? card.placeholder
    }

    private func makeCards() {
        cards.forEach { $0.removeFromSuperview() }
        cards = catalogue.map { card in
            let view = WidgetGalleryCard(card, showing: preview(of: card))
            view.spot = placed[card.id]
            view.onPick = { [weak self] in self?.onPick?(card.id) }
            view.onDragEnd = { [weak self] in self?.onDragEnd?() }
            board.addSubview(view)
            return view
        }
        needsLayout = true
    }

    private func showPlaced() {
        for card in cards {
            card.spot = placed[card.card.id]
        }
        count.stringValue = "\(placed.count) \(placed.count == 1 ? "widget" : "widgets") added"
    }

    private func paintChips() {
        for (chip, choice) in zip(chips, [nil] + Group.allCases) {
            chip.isOn = choice == group
        }
    }

    private func arrange() {
        let visible = shown
        let width = scroll.contentSize.width
        let columns = CGFloat(WidgetGrid.columns)
        let cell =
            (width - WidgetGrid.inset - WidgetGrid.inset - (columns - 1) * WidgetGrid.gap)
            / columns
        let step = Self.cardHeight + Self.rowGap
        let cells = WidgetGrid.cells(spanning: visible.map(\.size))
        for card in cards {
            card.isHidden = !visible.contains(card)
        }
        for (card, place) in zip(visible, cells) {
            card.frame = NSRect(
                x: WidgetGrid.inset + CGFloat(place.columns.lowerBound) * (cell + WidgetGrid.gap),
                y: Self.gridTop + CGFloat(place.row) * step,
                width: CGFloat(place.columns.count) * (cell + WidgetGrid.gap) - WidgetGrid.gap,
                height: Self.cardHeight)
        }
        let rows = CGFloat(cells.last.map { $0.row + 1 } ?? 0)
        board.frame.size = NSSize(
            width: width, height: Self.gridTop + rows * step + Self.bottomRoom)
        empty.isHidden = !visible.isEmpty
        let words = query.trimmingCharacters(in: .whitespaces)
        emptyText.stringValue =
            if !words.isEmpty {
                "No widgets match “\(words)”"
            } else if let group {
                "No \(group.title.lowercased()) widgets yet"
            } else {
                "No widgets yet"
            }
        emptySymbol.image = NSImage(
            systemSymbolName: words.isEmpty ? "square.grid.2x2" : "magnifyingglass",
            accessibilityDescription: nil)
    }
}
