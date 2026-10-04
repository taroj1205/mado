import AppKit

extension LauncherView {
    static let editTitle = "Edit Widgets"
    static let doneTitle = "Done"
    static let editHint = "Drag to reorder · ⌫ removes the selected widget"
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
        showAction(of: results.selectedItem)
    }

    func dragWidget(_ id: String?, at point: NSPoint, from source: Any?) -> NSDragOperation {
        guard let id else { return [] }
        guard widgetGrid.widgets.contains(where: { $0.id == id }) else {
            guard editingWidgets else { return [] }
            widgetGrid.incoming = (source as? WidgetGalleryCard)?.card.size.span ?? 1
            return .copy
        }
        var overTile = false
        changeWidgets { overTile = widgetGrid.preview(moving: id, to: point) }
        return overTile || editingWidgets ? .move : []
    }

    func endWidgetDrag() {
        changeWidgets { widgetGrid.endDrag() }
    }

    func dropWidget(_ id: String?) -> Bool {
        guard let id, editingWidgets || widgetGrid.widgets.contains(where: { $0.id == id })
        else { return false }
        let order = widgetGrid.shown.map(\.id)
        let moved = order != widgetGrid.widgets.map(\.id).filter(order.contains)
        let edit: WidgetSettings.Edit? =
            if widgetGrid.incoming != nil {
                .add(id)
            } else if moved, let index = order.firstIndex(of: id) {
                .move(id, before: order.dropFirst(index + 1).first)
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
