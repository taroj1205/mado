import AppKit

extension LauncherView {
    public var showsGrid: Bool { gridHome != nil }

    var selectedItem: ResultList.Item? {
        showsGrid ? emojiGrid.selectedItem : results.selectedItem
    }

    func placeGrid(below separator: NSView) {
        NSLayoutConstraint.activate([
            emojiGrid.leadingAnchor.constraint(equalTo: leadingAnchor),
            emojiGrid.trailingAnchor.constraint(equalTo: trailingAnchor),
            emojiGrid.topAnchor.constraint(equalTo: separator.bottomAnchor),
            emojiGrid.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        emojiGrid.onSelect = { [weak self] item in self?.selectionChanged(to: item) }
        emojiGrid.onMove = { [weak self] in self?.selectionMoved() }
        emojiGrid.onPick = { [weak self] item in
            if item.action.isEmpty {
                self?.run(keyed: Action.secondaryKeys)
            } else {
                self?.run(0)
            }
        }
        emojiGrid.onTab = { [weak self] tab in self?.pressTab(tab) }
    }

    func showGrid(_ sections: [ResultList.Section], home: String?, keeping id: String?) {
        let changed = showsGrid != (home != nil)
        gridHome = home
        results.isHidden = home != nil || showsLyrics
        emojiGrid.isHidden = home == nil
        if home != nil {
            emojiGrid.show(sections, keeping: id)
        }
        if changed {
            onFit?()
        }
    }

    func gridCommand(_ selector: Selector) -> Bool {
        let direction: EmojiGrid.Direction? =
            switch selector {
            case #selector(NSResponder.moveUp): .above
            case #selector(NSResponder.moveDown): .below
            case #selector(NSResponder.moveLeft): .left
            case #selector(NSResponder.moveRight): .right
            default: nil
            }
        guard let direction else { return false }
        return emojiGrid.move(direction) || direction == .above || direction == .below
    }

    private func pressTab(_ tab: EmojiGrid.Tab) {
        if emojiGrid.sections.contains(where: { $0.title == tab.section }) {
            emojiGrid.scroll(toSection: tab.section)
            return
        }
        replaceQuery(with: gridHome ?? "")
        afterResults = { [weak self] in self?.emojiGrid.scroll(toSection: tab.section) }
    }

    func gridContext() -> (text: NSAttributedString, glyph: String?)? {
        guard showsGrid, let item = emojiGrid.selectedItem else { return nil }
        let text = StatusPill.styled(
            bold: "", rest: [item.title, item.subtitle].joined(separator: " · "))
        return (text, item.glyph)
    }
}
