public import AppKit

extension LauncherView {
    public struct Chip: Equatable, Sendable {
        public let title: String
        public let symbol: String

        public init(title: String, symbol: String) {
            self.title = title
            self.symbol = symbol
        }
    }

    public enum Detail {
        case preview((ResultList.Item) -> Preview?)
        case comparison((ResultList.Item) -> Comparison?)
    }

    public var scoped: Bool { rootQuery != nil }

    var homeShown: Bool {
        !shownQuery.scoped
            && shownQuery.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func show(_ sections: [ResultList.Section], gridHome: String? = nil) {
        guard !editingWidgets else { return }
        shownQuery = (field.stringValue, scoped)
        if !homeShown {
            leavePillsAndWidgets()
        }
        let previewed = results.selectedItem?.file
        let keep = browsing || choosingAction || selectedPill != nil || selectedWidget != nil
        let kept = keep ? selectedItem?.id : nil
        if gridHome == nil {
            showGrid([], home: nil, keeping: nil)
            results.update(sections, keepingSelectionOf: kept)
        } else {
            showGrid(sections, home: gridHome, keeping: kept)
        }
        if results.selectedItem?.file != previewed || showsGrid {
            closePreview()
        }
        let waiting = afterResults
        afterResults = nil
        waiting?()
    }

    public func enter(
        placeholder: String, chip: Chip? = nil, filter: NSPopUpButton? = nil,
        detail: Detail? = nil
    ) {
        rootQuery = rootQuery ?? field.stringValue
        showScope(placeholder: placeholder, chip: chip)
        show(filter: filter)
        split(detail)
        replaceQuery(with: "")
    }

    @objc
    public func leave() {
        guard let query = rootQuery else { return }
        rootQuery = nil
        showScope(placeholder: nil, chip: nil)
        show(filter: nil)
        split(nil)
        Thumbnails.shared.removeAll()
        onLeave?()
        replaceQuery(with: query)
    }

    func replaceQuery(with query: String) {
        field.stringValue = query
        field.currentEditor()?.selectedRange = NSRange(location: query.utf16.count, length: 0)
        endBrowsing()
        onQuery?(query)
    }

    func placeDetail(below separator: NSView) {
        for (pane, listWidth) in [
            (detail, DetailPane.listWidth), (comparisonPane, ComparisonPane.listWidth),
        ] as [(NSView, CGFloat)] {
            NSLayoutConstraint.activate([
                pane.leadingAnchor.constraint(equalTo: leadingAnchor, constant: listWidth - 1),
                pane.trailingAnchor.constraint(equalTo: trailingAnchor),
                pane.topAnchor.constraint(equalTo: separator.bottomAnchor),
                pane.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    func openFilter(_ key: String) -> Bool {
        guard key == "p", let filter else { return false }
        filter.performClick(nil)
        return true
    }

    func showDetail(of item: ResultList.Item?) {
        switch shownDetail {
        case .preview(let preview):
            detail.show(item.flatMap(preview))

        case .comparison(let compare):
            detail.show(nil)
            comparisonPane.show(item.flatMap(compare))

        case nil:
            detail.show(nil)
        }
    }

    func placeSearchBar(_ bar: NSLayoutGuide) {
        chip.onPress = { [weak self] in self?.leave() }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.searchBarHeight),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.searchInset),
            icon.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            back.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.backInset),
            back.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            chip.leadingAnchor.constraint(
                equalTo: icon.trailingAnchor, constant: Self.searchIconGap),
            chip.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            fieldLeading,
            fieldTrailing,
            field.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
    }

    public func refreshDetail() {
        showDetail(of: selectedItem)
    }

    private func show(filter popUp: NSPopUpButton?) {
        filter?.removeFromSuperview()
        filter = popUp
        fieldTrailing.isActive = false
        if let popUp {
            popUp.translatesAutoresizingMaskIntoConstraints = false
            popUp.setContentHuggingPriority(.required, for: .horizontal)
            addSubview(popUp)
            fieldTrailing = field.trailingAnchor.constraint(
                equalTo: popUp.leadingAnchor, constant: -Self.searchIconGap)
            NSLayoutConstraint.activate([
                popUp.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.backInset),
                popUp.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            ])
        } else {
            fieldTrailing = field.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.searchInset)
        }
        fieldTrailing.isActive = true
    }

    private func split(_ shown: Detail?) {
        shownDetail = shown
        let listWidth: CGFloat? =
            switch shown {
            case .preview: DetailPane.listWidth
            case .comparison: ComparisonPane.listWidth
            case nil: nil
            }
        let previews = if case .preview = shown { true } else { false }
        let compares = if case .comparison = shown { true } else { false }
        results.compact = previews
        detail.isHidden = !previews
        comparisonPane.isHidden = !compares
        resultsTrailing.isActive = false
        resultsTrailing =
            listWidth.map { width in
                results.trailingAnchor.constraint(
                    equalTo: leadingAnchor, constant: width - Self.resultsInset)
            }
            ?? results.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.resultsInset)
        resultsTrailing.isActive = true
        showDetail(of: selectedItem)
    }

    private func showScope(placeholder: String?, chip shown: Chip?) {
        let inside = placeholder != nil
        icon.isHidden = inside && shown == nil
        back.isHidden = !inside || shown != nil
        chip.show(shown)
        let leading: NSView = shown != nil ? chip : inside ? back : icon
        fieldLeading.isActive = false
        fieldLeading = field.leadingAnchor.constraint(
            equalTo: leading.trailingAnchor, constant: Self.searchIconGap)
        fieldLeading.isActive = true
        field.placeholderString = placeholder ?? Self.searchPlaceholder
    }
}
