public import AppKit

extension LauncherView {
    public var scoped: Bool { rootQuery != nil }

    var onEmptyRootQuery: Bool {
        !scoped && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func enter(
        placeholder: String, filter: NSPopUpButton? = nil,
        preview: ((ResultList.Item) -> Preview?)? = nil
    ) {
        rootQuery = rootQuery ?? field.stringValue
        showScope(placeholder: placeholder)
        show(filter: filter)
        split(preview)
        replaceQuery(with: "")
    }

    @objc
    public func leave() {
        guard let query = rootQuery else { return }
        rootQuery = nil
        showScope(placeholder: nil)
        show(filter: nil)
        split(nil)
        Thumbnails.shared.removeAll()
        replaceQuery(with: query)
    }

    func replaceQuery(with query: String) {
        field.stringValue = query
        field.currentEditor()?.selectedRange = NSRange(location: query.utf16.count, length: 0)
        endBrowsing()
        onQuery?(query)
    }

    func placeDetail(below separator: NSView) {
        NSLayoutConstraint.activate([
            detail.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: DetailPane.listWidth - 1),
            detail.trailingAnchor.constraint(equalTo: trailingAnchor),
            detail.topAnchor.constraint(equalTo: separator.bottomAnchor),
            detail.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func openFilter(_ key: String) -> Bool {
        guard key == "p", let filter else { return false }
        filter.performClick(nil)
        return true
    }

    func showDetail(of item: ResultList.Item?) {
        detail.show(item.flatMap { previewer?($0) })
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

    private func split(_ preview: ((ResultList.Item) -> Preview?)?) {
        previewer = preview
        results.compact = preview != nil
        detail.isHidden = preview == nil
        resultsTrailing.isActive = false
        resultsTrailing =
            preview == nil
            ? results.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.resultsInset)
            : results.trailingAnchor.constraint(
                equalTo: leadingAnchor, constant: DetailPane.listWidth - Self.resultsInset)
        resultsTrailing.isActive = true
        showDetail(of: results.selectedItem)
    }

    private func showScope(placeholder: String?) {
        let inside = placeholder != nil
        icon.isHidden = inside
        back.isHidden = !inside
        let leading: NSView = inside ? back : icon
        fieldLeading.isActive = false
        fieldLeading = field.leadingAnchor.constraint(
            equalTo: leading.trailingAnchor, constant: Self.searchIconGap)
        fieldLeading.isActive = true
        field.placeholderString = placeholder ?? Self.searchPlaceholder
    }
}
