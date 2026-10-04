import AppKit

extension LauncherView {
    static let editTitle = "Edit Widgets"
    static let doneTitle = "Done"
    static let editHint = "Drag a widget anywhere around the panel · ⌫ removes the selected one"
    static let editSymbol = "square.grid.2x2"
    private static let editInset: CGFloat = 14
    private static let dimmed: CGFloat = 0.45

    func placeEditBar() {
        addSubview(editBar)
        NSLayoutConstraint.activate([
            editBar.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            editBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.editInset),
            editBar.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
        ])
        editBar.onAdd = { [weak self] in self?.onAddWidgets?() }
        editBar.onDone = { [weak self] in self?.finishEditingWidgets() }
        editBar.onRemove = { [weak self] in self?.removeSelectedWidget() }
        editBar.onStep = { [weak self] step in self?.stepWidget(by: step) }
        widgetGrid.onDrag = { [weak self] id, point, source in
            guard let self, let window = unsafe window else { return [] }
            return dragWidget(id, at: window.convertPoint(fromScreen: point), from: source)
        }
        widgetGrid.onDrop = { [weak self] id in self?.dropWidget(id) ?? false }
        widgetGrid.onDragEnd = { [weak self] in self?.endWidgetDrag() }
        registerForDraggedTypes([WidgetGrid.dragType])
    }

    func editWidgets() {
        guard showsWidgets, !editingWidgets else { return }
        closeActions()
        closePreview()
        closeCustomiser()
        editingWidgets = true
        changeWidgets { widgetGrid.editing = true }
        showEditing()
        unsafe window?.makeFirstResponder(editBar)
    }

    func finishEditingWidgets() {
        guard editingWidgets else { return }
        editingWidgets = false
        changeWidgets { widgetGrid.editing = false }
        showEditing()
        unsafe window?.makeFirstResponder(field)
        onEndEditingWidgets?()
    }

    func removeWidget(_ index: Int) {
        onWidgetEdit?(.remove(widgetGrid.shown[index].id))
    }

    private func removeSelectedWidget() {
        if let selectedWidget {
            removeWidget(selectedWidget)
        }
    }

    private func stepWidget(by step: Int) {
        let count = widgetGrid.shown.count
        guard count > 0 else { return }
        selectWidget(selectedWidget.map { min(max($0 + step, 0), count - 1) } ?? 0)
    }

    private func showEditing() {
        icon.image = NSImage(
            systemSymbolName: editingWidgets ? Self.editSymbol : Self.searchSymbol,
            accessibilityDescription: nil)
        field.isHidden = editingWidgets
        editBar.isHidden = !editingWidgets
        results.alphaValue = editingWidgets ? Self.dimmed : 1
        results.hidesSelection = editingWidgets || selectedWidget != nil
        showAction(of: selectedItem)
    }

    func dragWidget(_ id: String?, at point: NSPoint, from source: Any?) -> NSDragOperation {
        guard let id else { return [] }
        guard widgetGrid.widgets.contains(where: { $0.id == id }) else {
            guard editingWidgets else { return [] }
            widgetGrid.incoming = (source as? WidgetGalleryCard)?.card.size.span ?? 1
            return .copy
        }
        var droppable = false
        changeWidgets { droppable = widgetGrid.preview(moving: id, to: point) }
        return droppable || (editingWidgets && widgetGrid.refused == nil) ? .move : []
    }

    private func firstHidden(after widget: String?, shown: [String]) -> String? {
        widgetGrid.widgets.map(\.id).drop { $0 != widget }.dropFirst().first { !shown.contains($0) }
    }

    func endWidgetDrag() {
        changeWidgets { widgetGrid.endDrag() }
    }

    func dropWidget(_ id: String?) -> Bool {
        guard let id, editingWidgets || widgetGrid.widgets.contains(where: { $0.id == id }),
            widgetGrid.refused == nil
        else {
            endWidgetDrag()
            return false
        }
        let spot = widgetGrid.shown.first { $0.id == id }.map(widgetGrid.spot)
        let order = widgetGrid.shown.filter { widgetGrid.spot(of: $0) == spot }.map(\.id)
        let all = widgetGrid.widgets.map(\.id)
        let before = order.firstIndex(of: id).map { index in
            order.dropFirst(index + 1).first
                ?? firstHidden(after: order.dropLast().last, shown: order)
        }
        let edit: WidgetSettings.Edit? =
            if widgetGrid.incoming != nil {
                .add(id)
            } else if let spot, let before, spot != widgetGrid.home(of: id) {
                .place(id, spot, before: before)
            } else if order != all.filter(order.contains), let before {
                .move(id, before: before)
            } else {
                nil
            }
        endWidgetDrag()
        if let edit {
            onWidgetEdit?(edit)
        }
        return true
    }
}
