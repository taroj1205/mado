public import AppKit

public final class WidgetGallery: NSView {
    public enum Size: Sendable {
        case small
        case wide
        case large

        var title: String {
            switch self {
            case .small: "Small"
            case .wide: "Wide"
            case .large: "Large"
            }
        }
    }

    public enum Group: CaseIterable, Sendable {
        case time
        case system
        case extensions

        var title: String {
            switch self {
            case .time: "Time"
            case .system: "System"
            case .extensions: "From extensions"
            }
        }
    }

    public struct Card {
        public let id: String
        public let name: String
        public let summary: String
        public let size: Size
        public let group: Group
        public let symbol: String
        public let colour: NSColor

        public init(
            id: String, name: String, summary: String, size: Size, group: Group, symbol: String,
            colour: NSColor
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.size = size
            self.group = group
            self.symbol = symbol
            self.colour = colour
        }
    }

    static let columns = 4
    private static let gap: CGFloat = 10
    private static let top: CGFloat = 6
    private static let side: CGFloat = 20
    private static let footerY: CGFloat = 14
    private static let countSize: CGFloat = 12.5

    public let filter = NSSegmentedControl(
        labels: ["All"] + Group.allCases.map(\.title), trackingMode: .selectOne, target: nil,
        action: nil)
    public var onAdd: ((String) -> Void)?
    public var onDone: (() -> Void)?

    public var added: [String] = [] {
        didSet { update() }
    }

    let cards: [WidgetGalleryCard]
    let grid = NSStackView()
    let count = NSTextField(labelWithString: "")
    let done = NSButton(title: "Done", target: nil, action: nil)

    var shown: [WidgetGalleryCard] {
        let group = filter.selectedSegment > 0 ? Group.allCases[filter.selectedSegment - 1] : nil
        return cards.filter { group == nil || $0.card.group == group }
    }

    public init(cards: [Card]) {
        self.cards = cards.map(WidgetGalleryCard.init)
        super.init(frame: .zero)
        for card in self.cards {
            let id = card.card.id
            card.onAdd = { [weak self] in self?.onAdd?(id) }
        }
        filter.selectedSegment = 0
        filter.target = self
        filter.action = #selector(filterChanged)
        filter.setAccessibilityLabel("Show")
        grid.orientation = .vertical
        grid.spacing = Self.gap
        count.font = .systemFont(ofSize: Self.countSize)
        count.textColor = .secondaryLabelColor
        done.bezelStyle = .push
        done.keyEquivalent = "\r"
        done.target = self
        done.action = #selector(finish)
        let line = NSBox()
        line.boxType = .separator
        let footer = NSStackView(views: [count, NSView(), done])
        footer.edgeInsets = NSEdgeInsets(
            top: Self.footerY, left: Self.side, bottom: Self.footerY, right: Self.side)
        for view in [grid, line, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: Self.top),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.side),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        layOutGrid()
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func update() {
        for card in cards {
            card.isAdded = added.contains(card.card.id)
        }
        count.stringValue =
            "\(added.count) \(added.count == 1 ? "widget" : "widgets") on the empty query"
    }

    private func layOutGrid() {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let visible = shown
        for start in stride(from: 0, to: visible.count, by: Self.columns) {
            let row = Array(visible[start..<min(start + Self.columns, visible.count)])
            let fillers = (row.count..<Self.columns).map { _ in NSView() }
            let stack = NSStackView(views: row + fillers)
            stack.distribution = .fillEqually
            stack.alignment = .top
            stack.spacing = Self.gap
            grid.addArrangedSubview(stack)
            stack.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        }
    }

    @objc
    private func filterChanged() {
        layOutGrid()
    }

    @objc
    private func finish() {
        onDone?()
    }
}
