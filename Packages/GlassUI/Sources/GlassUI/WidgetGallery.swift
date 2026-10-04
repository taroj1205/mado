public import AppKit

public final class WidgetGallery: NSView {
    static let columns = 4
    private static let gap: CGFloat = 10
    private static let top: CGFloat = 6
    private static let side: CGFloat = 20
    private static let footerY: CGFloat = 14
    private static let countSize: CGFloat = 12.5
    private static let doneHeight: CGFloat = 30
    private static let emptySymbolSize: CGFloat = 26
    private static let emptyTitleSize: CGFloat = 13
    private static let emptyGap: CGFloat = 10
    private static let fade: TimeInterval = 0.18

    public let filter = NSSegmentedControl(
        labels: ["All"] + Group.allCases.map(\.title), trackingMode: .selectOne, target: nil,
        action: nil)
    public var onAdd: ((String) -> Void)?
    public var onDone: (() -> Void)?

    public var added: [String] = [] {
        didSet { update() }
    }

    public var hintsDrag = false {
        didSet { update() }
    }

    let cards: [WidgetGalleryCard]
    let grid = NSStackView()
    let count = NSTextField(labelWithString: "")
    let done = PillButton("Done", height: doneHeight)
    let empty = NSStackView()
    private let emptySymbol = NSImageView()
    private let emptyTitle = NSTextField(labelWithString: "")

    var shown: [WidgetGalleryCard] {
        cards.filter { group == nil || $0.card.group == group }
    }

    private var group: Group? {
        filter.selectedSegment > 0 ? Group.allCases[filter.selectedSegment - 1] : nil
    }

    private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

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
        setUpEmpty()
        let line = NSBox()
        line.boxType = .separator
        let footer = footerRow()
        let body = NSLayoutGuide()
        addLayoutGuide(body)
        for view in [grid, empty, line, footer] {
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
            body.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            body.bottomAnchor.constraint(equalTo: line.topAnchor),
            empty.centerXAnchor.constraint(equalTo: centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: body.centerYAnchor),
        ])
        layOutGrid()
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func setUpEmpty() {
        emptySymbol.symbolConfiguration = .init(pointSize: Self.emptySymbolSize, weight: .light)
        emptySymbol.contentTintColor = .tertiaryLabelColor
        emptyTitle.font = .systemFont(ofSize: Self.emptyTitleSize, weight: .medium)
        emptyTitle.textColor = .secondaryLabelColor
        empty.setViews([emptySymbol, emptyTitle], in: .center)
        empty.orientation = .vertical
        empty.spacing = Self.emptyGap
    }

    private func footerRow() -> NSStackView {
        count.font = .systemFont(ofSize: Self.countSize)
        count.textColor = .secondaryLabelColor
        done.keyEquivalent = "\r"
        done.target = self
        done.action = #selector(finish)
        let footer = NSStackView(views: [count, NSView(), done])
        footer.edgeInsets = NSEdgeInsets(
            top: Self.footerY, left: Self.side, bottom: Self.footerY, right: Self.side)
        footer.heightAnchor.constraint(
            equalToConstant: Self.footerY + Self.doneHeight + Self.footerY
        )
        .isActive = true
        return footer
    }

    private func update() {
        for card in cards {
            card.isAdded = added.contains(card.card.id)
        }
        let total = "\(added.count) \(added.count == 1 ? "widget" : "widgets") on the empty query"
        count.stringValue =
            hintsDrag ? "\(total) · drag a card onto the launcher to place it" : total
    }

    private func fadeIn(_ views: [NSView]) {
        guard animates, unsafe window != nil else { return }
        for view in views {
            view.alphaValue = 0
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for view in views {
                view.animator().alphaValue = 1
            }
        }
    }

    private func layOutGrid() {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let visible = shown
        empty.isHidden = !visible.isEmpty
        if let group, visible.isEmpty {
            emptySymbol.image = NSImage(
                systemSymbolName: group.empty.symbol, accessibilityDescription: nil)
            emptyTitle.stringValue = group.empty.title
        }
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
        fadeIn([grid, empty])
    }

    @objc
    private func finish() {
        onDone?()
    }
}
