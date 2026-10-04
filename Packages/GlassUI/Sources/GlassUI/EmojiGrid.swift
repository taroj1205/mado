public import AppKit

public final class EmojiGrid: NSView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    public struct Tab: Equatable, Sendable {
        public let title: String
        public let symbol: String
        public let section: String

        public init(title: String, symbol: String, section: String) {
            self.title = title
            self.symbol = symbol
            self.section = section
        }
    }

    enum Direction {
        case above
        case below
        case left
        case right
    }

    static let columns = 12
    static let cellHeight: CGFloat = 48
    static let gap: CGFloat = 4
    static let side: CGFloat = 8
    static let headerHeight: CGFloat = 33
    private static let tabRowHeight: CGFloat = 42
    private static let tabInset: CGFloat = 12
    private static let tabGap: CGFloat = 2
    private static let bottomInset: CGFloat = 60

    public var tabs: [Tab] = [] {
        didSet {
            if tabs != oldValue { tabBar.show(tabs) }
        }
    }

    public var accessory: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            placeAccessory()
        }
    }

    var onSelect: ((ResultList.Item?) -> Void)?
    var onMove: (() -> Void)?
    var onPick: ((ResultList.Item) -> Void)?
    var onTab: ((Tab) -> Void)?
    private(set) var sections: [ResultList.Section] = []
    private(set) var selected: IndexPath?
    let collection = EmojiCollection()
    let tabBar = EmojiTabBar()
    private let scroll = NSScrollView()
    private let notice = NSTextField(labelWithString: "")
    private let flow = NSCollectionViewFlowLayout()

    var selectedItem: ResultList.Item? {
        selected.map { sections[$0.section].items[$0.item] }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        flow.minimumInteritemSpacing = Self.gap
        flow.minimumLineSpacing = Self.gap
        flow.sectionInset = NSEdgeInsets(top: 0, left: Self.side, bottom: 0, right: Self.side)
        flow.headerReferenceSize = NSSize(width: 0, height: Self.headerHeight)
        collection.collectionViewLayout = flow
        collection.backgroundColors = [.clear]
        collection.isSelectable = true
        collection.allowsEmptySelection = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(EmojiCell.self, forItemWithIdentifier: EmojiCell.id)
        collection.register(
            EmojiHeader.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: EmojiHeader.id)
        collection.onDoubleClick = { [weak self] in
            if let item = self?.selectedItem { self?.onPick?(item) }
        }
        scroll.documentView = collection
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: Self.bottomInset, right: 0)
        notice.textColor = .secondaryLabelColor
        notice.alignment = .center
        tabBar.onPress = { [weak self] index in
            guard let self, tabs.indices.contains(index) else { return }
            onTab?(tabs[index])
        }
        place()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func layout() {
        super.layout()
        let width =
            scroll.contentSize.width - flow.sectionInset.left - flow.sectionInset.right
            - Self.gap * CGFloat(Self.columns - 1)
        let itemWidth = floor(width / CGFloat(Self.columns))
        if flow.itemSize.width != itemWidth {
            flow.itemSize = NSSize(width: itemWidth, height: Self.cellHeight)
        }
    }

    private func place() {
        for view in [tabBar, scroll, notice] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.tabInset),
            tabBar.heightAnchor.constraint(equalToConstant: Self.tabRowHeight),
            scroll.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            notice.centerXAnchor.constraint(equalTo: centerXAnchor),
            notice.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            notice.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
        ])
    }

    private func placeAccessory() {
        guard let accessory else { return }
        accessory.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessory)
        NSLayoutConstraint.activate([
            accessory.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.tabInset),
            accessory.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            accessory.leadingAnchor.constraint(
                greaterThanOrEqualTo: tabBar.trailingAnchor, constant: Self.tabInset),
        ])
    }

    func show(_ shown: [ResultList.Section], keeping id: String?) {
        let message = shown.lazy.compactMap(\.notice).first
        sections = shown.filter { !$0.items.isEmpty }
        notice.stringValue = message.map { "\($0.title)\n\($0.detail)" } ?? ""
        notice.isHidden = message == nil
        collection.reloadData()
        let kept = id.flatMap(indexPath(of:))
        let preferred = sections.firstIndex(where: \.selectsFirst).map { section in
            IndexPath(item: 0, section: section)
        }
        select(kept ?? preferred ?? (sections.isEmpty ? nil : IndexPath(item: 0, section: 0)))
        if kept == nil {
            scroll.contentView.scroll(to: .zero)
            if let selected {
                collection.scrollToItems(at: [selected], scrollPosition: .nearestHorizontalEdge)
            }
        }
    }

    private func indexPath(of id: String) -> IndexPath? {
        for (section, shown) in sections.enumerated() {
            if let item = shown.items.firstIndex(where: { $0.id == id }) {
                return IndexPath(item: item, section: section)
            }
        }
        return nil
    }

    func select(_ indexPath: IndexPath?) {
        selected = indexPath
        collection.selectionIndexPaths = Set([indexPath].compactMap(\.self))
        if let indexPath {
            collection.scrollToItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
        }
        let section = indexPath.map { sections[$0.section].title }
        tabBar.highlight(tabs.firstIndex { $0.section == section } ?? (tabs.isEmpty ? nil : 0))
        onSelect?(selectedItem)
    }

    func scroll(toSection title: String) {
        guard let section = sections.firstIndex(where: { $0.title == title }) else { return }
        let first = IndexPath(item: 0, section: section)
        select(first)
        onMove?()
        let header = collection.layoutAttributesForSupplementaryElement(
            ofKind: NSCollectionView.elementKindSectionHeader, at: first)
        if let frame = header?.frame {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: frame.minY))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    @discardableResult
    func move(_ direction: Direction) -> Bool {
        guard let selected else { return false }
        let next = Self.step(
            from: selected, direction, counts: sections.map(\.items.count), columns: Self.columns)
        guard let next else { return false }
        select(next)
        onMove?()
        return true
    }

    public func numberOfSections(in _: NSCollectionView) -> Int {
        sections.count
    }

    public func collectionView(_: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    public func collectionView(
        _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: EmojiCell.id, for: indexPath)
        (cell as? EmojiCell)?.show(sections[indexPath.section].items[indexPath.item])
        return cell
    }

    public func collectionView(
        _ collectionView: NSCollectionView,
        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
        at indexPath: IndexPath
    ) -> NSView {
        let view = collectionView.makeSupplementaryView(
            ofKind: kind, withIdentifier: EmojiHeader.id, for: indexPath)
        (view as? EmojiHeader)?.label.stringValue = sections[indexPath.section].title
        return view
    }

    public func collectionView(
        _: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        guard let indexPath = indexPaths.first, indexPath != selected else { return }
        select(indexPath)
        onMove?()
    }
}
