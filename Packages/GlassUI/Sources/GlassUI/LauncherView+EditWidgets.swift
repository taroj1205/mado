import AppKit

extension LauncherView {
    static let editTitle = "Edit Widgets"
    static let editPlaceholder = "Search widgets…"
    static let editHint = "Click a widget to add it · drag one anywhere · ⇧-click to group"
    static let editSymbol = "square.grid.2x2"
    static let doneHeight: CGFloat = 28
    private static let doneInset: CGFloat = 14

    private static func heading(of event: NSEvent) -> WidgetGrid.Heading? {
        switch event.specialKey {
        case .upArrow: .top
        case .downArrow: .bottom
        case .leftArrow: .left
        case .rightArrow: .right
        default: nil
        }
    }

    func placeEditing() {
        for view in [gallery, doneButton, editBar] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isHidden = true
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            gallery.leadingAnchor.constraint(equalTo: leadingAnchor),
            gallery.trailingAnchor.constraint(equalTo: trailingAnchor),
            gallery.topAnchor.constraint(equalTo: widgetGrid.bottomAnchor),
            gallery.bottomAnchor.constraint(equalTo: bottomAnchor),
            doneButton.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.doneInset),
            doneButton.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            editBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.capsuleInset),
            editBar.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.capsuleInset),
            editBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        doneButton.onPress = { [weak self] in self?.finishEditingWidgets() }
        editBar.onMove = { [weak self] in self?.toggleSpotPicker() }
        editBar.onGroup = { [weak self] in self?.groupWidgets() }
        editBar.onUngroup = { [weak self] in self?.ungroupWidget() }
        editBar.onRemove = { [weak self] in self?.removeSelectedWidget() }
        editBar.onUndo = { [weak self] in _ = self?.undoWidgetEdit() }
        gallery.onPick = { [weak self] id in self?.pickFromGallery(id) }
        gallery.onDragEnd = { [weak self] in self?.endWidgetDrag() }
        widgetGrid.onDrag = { [weak self] id, point, source in
            guard let self, let window = unsafe window else { return [] }
            return dragWidget(id, at: window.convertPoint(fromScreen: point), from: source)
        }
        widgetGrid.onDrop = { [weak self] id in self?.dropWidget(id) ?? false }
        widgetGrid.onDragEnd = { [weak self] in self?.endWidgetDrag() }
        registerForDraggedTypes([WidgetGrid.dragType])
    }

    public func editWidgets() {
        guard !editingWidgets else { return }
        if !scoped, !field.stringValue.isEmpty {
            queryBeforeEditing = field.stringValue
            field.stringValue = ""
            onQuery?("")
        }
        guard !waitsForResults(then: { $0.editWidgets() }), homeShown else { return }
        closeActions()
        closePreview()
        closeCustomiser()
        editingWidgets = true
        widgetNote = nil
        field.stringValue = ""
        changeWidgets { widgetGrid.editing = true }
        showEditing()
        unsafe window?.makeFirstResponder(field)
        onWidgetEditing?(true)
    }

    func finishEditingWidgets() {
        guard editingWidgets else { return }
        editingWidgets = false
        closeSpotPicker()
        widgetNote = nil
        field.stringValue = shownQuery.text
        restoreQueryBeforeEditing()
        gallery.query = ""
        changeWidgets { widgetGrid.editing = false }
        showEditing()
        unsafe window?.makeFirstResponder(field)
        onWidgetEditing?(false)
        onQuery?(field.stringValue)
    }

    func restoreQueryBeforeEditing() {
        if let queryBeforeEditing, field.stringValue.isEmpty {
            field.stringValue = queryBeforeEditing
        }
        queryBeforeEditing = nil
    }

    func report(_ edit: WidgetSettings.Edit) {
        let selected = selectedWidget.map { widgetGrid.shown[$0].id }
        let id = selected.flatMap { edit.ids.contains($0) ? $0 : nil } ?? edit.id
        let text = describe(edit)
        onWidgetEdit?(edit)
        guard editingWidgets else { return }
        if edit != .remove(id), let index = widgetGrid.shown.firstIndex(where: { $0.id == id }) {
            selectWidget(index)
        }
        note(text, undoable: true)
    }

    func undoWidgetEdit() -> Bool {
        guard editingWidgets, widgetNote?.undoable == true else { return false }
        onUndoWidgetEdit?()
        note("Undone", undoable: false)
        return true
    }

    func overlayShortcut(_ event: NSEvent) -> Bool {
        guard editingWidgets else { return actionPanel?.performShortcut(event) == true }
        let flags = event.modifierFlags.intersection(Self.modifierKeys)
        switch (flags, event.charactersIgnoringModifiers?.lowercased()) {
        case (.command, "z"): return undoWidgetEdit()

        case (.command, "g"):
            groupWidgets()
            return true

        case ([.command, .shift], "g"):
            ungroupWidget()
            return true

        case (.command, "="), (.command, "-"):
            guard let selectedWidget else { return false }
            resizeWidget(selectedWidget, .step(event.charactersIgnoringModifiers == "=" ? 1 : -1))
            return true

        default: return false
        }
    }

    func editCommand(_ selector: Selector, in textView: NSTextView) -> Bool {
        if spotPicker != nil, let widget = selectedWidget {
            return pickerCommand(selector, moving: widgetGrid.shown[widget].id)
        }
        if textView.string.isEmpty, tileCommand(selector) {
            return true
        }
        switch selector {
        case #selector(NSResponder.moveUp): stepWidget(.top)
        case #selector(NSResponder.moveDown): stepWidget(.bottom)

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText():
            finishEditingWidgets()

        case #selector(NSResponder.cancelOperation): finishEditingWidgets()
        default: return false
        }
        return true
    }

    func handleWhileEditing(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            return moveWidgetKey(event)

        case .leftMouseDown:
            let point = event.locationInWindow
            let onMove = editBar.move.convert(editBar.move.bounds, to: nil).contains(point)
            if !onMove, spotPicker?.contains(point) != true {
                closeSpotPicker()
            }
            return false

        default: return false
        }
    }

    private func moveWidgetKey(_ event: NSEvent) -> Bool {
        guard selectedWidget != nil, let heading = Self.heading(of: event) else { return false }
        switch event.modifierFlags.intersection(Self.modifierKeys) {
        case .option: sendWidget(heading)
        case .shift where field.stringValue.isEmpty: extendWidgetSelection(toward: heading)
        default: return false
        }
        return true
    }

    func removeWidget(_ index: Int) {
        report(.remove(widgetGrid.shown[index].id))
    }

    func stepWidget(_ heading: WidgetGrid.Heading) {
        guard !widgetGrid.shown.isEmpty else { return }
        guard let selectedWidget else {
            selectWidget(0)
            return
        }
        selectWidget(widgetGrid.neighbour(of: selectedWidget, toward: heading) ?? selectedWidget)
    }

    func sendWidget(_ heading: WidgetGrid.Heading) {
        guard let selectedWidget else { return }
        let id = widgetGrid.shown[selectedWidget].id
        guard let spot = widgetGrid.next(from: id, toward: heading) else {
            NSSound.beep()
            return
        }
        place(id, at: spot)
    }

    func showWidgetTools() {
        editBar.isHidden = !editingWidgets
        guard editingWidgets else { return }
        let widget = selectedWidget.map { widgetGrid.shown[$0] }
        let picked = chosenWidgets
        let grouping: WidgetEditBar.Grouping =
            if picked.count > 1 {
                .group
            } else if let widget, widgetGrid.unit(of: widget.id).count > 1 {
                .ungroup
            } else {
                .off
            }
        editBar.show(
            widget.map { ($0.name, widgetGrid.home(of: $0.id)) }, moving: spotPicker != nil,
            count: picked.count, grouping: grouping)
        let hint = widgetNote ?? (widget == nil ? (Self.editHint, false) : nil)
        editBar.show(
            hint: hint?.text, symbol: widgetNote == nil ? WidgetEditBar.moveSymbol : "checkmark",
            undoable: hint?.undoable == true)
        gallery.placed = Dictionary(
            widgetGrid.widgets.map { ($0.id, widgetGrid.home(of: $0.id)) }
        ) { first, _ in first }
    }

    func dragWidget(_ id: String?, at point: NSPoint, from source: Any?) -> NSDragOperation {
        guard let id else { return [] }
        let known = widgetGrid.widgets.contains { $0.id == id }
        if !known {
            guard editingWidgets, let card = source as? WidgetGalleryCard, card.card.id == id
            else { return [] }
            widgetGrid.incoming = card.widget
        }
        var droppable = false
        changeWidgets { droppable = widgetGrid.preview(moving: id, to: point) }
        guard droppable else { return [] }
        return known ? .move : .copy
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
        let arriving = widgetGrid.incoming?.id == id
        let unit = arriving || spot == widgetGrid.home(of: id) ? [id] : widgetGrid.unit(of: id)
        let before = order.lastIndex(where: unit.contains).map { index in
            order.dropFirst(index + 1).first
                ?? firstHidden(after: order.last { !unit.contains($0) }, shown: order)
        }
        let edit: WidgetSettings.Edit? =
            if arriving {
                spot.map { .place(id, $0, before: before.flatMap(\.self)) }
            } else if let spot, let before, spot != widgetGrid.home(of: id) {
                .moving(unit, to: spot, before: before)
            } else if order != all.filter(order.contains), let before {
                .move(id, before: before)
            } else {
                nil
            }
        endWidgetDrag()
        if let edit {
            report(edit)
        }
        return !arriving || edit != nil
    }

    private func showEditing() {
        icon.image = NSImage(
            systemSymbolName: editingWidgets ? Self.editSymbol : Self.searchSymbol,
            accessibilityDescription: nil)
        field.placeholderString = editingWidgets ? Self.editPlaceholder : Self.searchPlaceholder
        doneButton.isHidden = !editingWidgets
        gallery.isHidden = !editingWidgets
        results.isHidden = editingWidgets || showsGrid
        results.hidesSelection = editingWidgets || selectedWidget != nil
        fieldTrailing.isActive = false
        fieldTrailing =
            editingWidgets
            ? field.trailingAnchor.constraint(
                equalTo: doneButton.leadingAnchor, constant: -Self.searchIconGap)
            : field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.searchInset)
        fieldTrailing.isActive = true
        showAction(of: selectedItem)
    }

    private func tileCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveLeft): stepWidget(.left)
        case #selector(NSResponder.moveRight): stepWidget(.right)

        case #selector(NSResponder.deleteBackward), #selector(NSResponder.deleteForward):
            removeSelectedWidget()

        default: return false
        }
        return true
    }

    private func pickFromGallery(_ id: String) {
        guard widgetGrid.widgets.contains(where: { $0.id == id }) else {
            report(.add(id))
            return
        }
        if let index = widgetGrid.shown.firstIndex(where: { $0.id == id }) {
            selectWidget(index)
        }
        note(
            "\(widgetName(of: id)) is \(widgetGrid.home(of: id).title)",
            undoable: widgetNote?.undoable == true)
    }

    private func describe(_ edit: WidgetSettings.Edit) -> String {
        let name = widgetName(of: edit.id)
        switch edit {
        case .add: return "\(name) added · \(WidgetGrid.Spot.panel.title)"
        case .move: return "\(name) moved"
        case .remove: return "\(name) removed"

        case let .place(id, spot, _):
            let added = !widgetGrid.widgets.contains { $0.id == id }
            return "\(name) \(added ? "added" : "moved") · \(spot.title)"

        case let .group(ids, spot, _):
            let moved = Set(widgetGrid.unit(of: edit.id)) == Set(ids)
            return "\(moved ? "Group moved" : "\(ids.count) widgets grouped") · \(spot.title)"

        case .spread: return "Ungrouped"

        case let .resize(_, columns):
            return "\(name) resized · \(columns) of \(WidgetGrid.columns) columns"
        }
    }

    func note(_ text: String, undoable: Bool) {
        widgetNote = (text, undoable)
        showWidgetTools()
        unsafe NSAccessibility.post(
            element: self, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func widgetName(of id: String) -> String {
        widgetGrid.widgets.first { $0.id == id }?.name
            ?? gallery.catalogue.first { $0.id == id }?.name ?? id
    }

    private func removeSelectedWidget() {
        if let selectedWidget {
            removeWidget(selectedWidget)
        }
    }

    private func toggleSpotPicker() {
        guard let selectedWidget else { return }
        if spotPicker == nil {
            openSpotPicker(for: widgetGrid.shown[selectedWidget])
        } else {
            closeSpotPicker()
        }
    }

    private func firstHidden(after widget: String?, shown: [String]) -> String? {
        widgetGrid.widgets.map(\.id).drop { $0 != widget }.dropFirst().first { !shown.contains($0) }
    }
}
