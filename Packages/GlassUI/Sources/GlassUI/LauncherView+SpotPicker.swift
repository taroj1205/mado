import AppKit

extension LauncherView {
    static let moveTitle = "Move…"
    static let addTitle = "Add Widgets…"
    static let removeTitle = "Remove Widget"

    func showActions(for widget: WidgetGrid.Widget) {
        var move = Action(Self.moveTitle)
        move.detail = widgetGrid.home(of: widget.id).title
        move.opens = true
        var remove = Action(Self.removeTitle, isDestructive: true)
        remove.group = 1
        let pin = pinAction(for: widget).map { [($0, nil as (() -> Void)?)] } ?? []
        let entries: [(action: Action, run: (() -> Void)?)] =
            [
                (
                    Action(widget.action, keys: Action.primaryKeys),
                    { [weak self] in self?.onWidget?(widget) }
                ),
                (move, { [weak self] in self?.openSpotPicker(for: widget) }),
            ] + pin + [
                (Action(Self.editTitle), { [weak self] in self?.editWidgets() }),
                (Action(Self.addTitle), { [weak self] in self?.addWidgets() }),
                (remove, { [weak self] in self?.report(.remove(widget.id)) }),
            ]
        present(entries.map(\.action), for: widget.name) { index in entries[index].run?() }
        actionPanel?.onOpen = { index in entries[index].run?() }
    }

    func openSpotPicker(for widget: WidgetGrid.Widget) {
        let panel = editingWidgets || widgetMenu != nil ? nil : actionPanel
        guard spotPicker == nil, editingWidgets || widgetMenu != nil || panel != nil else {
            return
        }
        let picker = WidgetSpotPicker(moving: widget.name, from: widgetGrid.home(of: widget.id))
        picker.onPick = { [weak self] spot in self?.place(widget.id, at: spot) }
        spotPicker = picker
        if widgetMenu != nil {
            closeSizeMenu()
        } else if let panel {
            panel.onCommand = { [weak self] selector in
                self?.pickerCommand(selector, moving: widget.id) ?? false
            }
        } else {
            showWidgetTools()
        }
        layoutSubtreeIfNeeded()
        placeSpotPicker()
    }

    func placeSpotPicker() {
        guard let picker = spotPicker, let window = unsafe window else { return }
        let size = WidgetSpotPicker.size
        let frame: NSRect
        if let widgetMenu {
            frame = beside(widgetMenu.panel.frame, size: size, leftFirst: false)
        } else if !editingWidgets, let actionPanel {
            frame = beside(screenFrame(of: actionPanel.glass), size: size, leftFirst: true)
        } else {
            let bar = screenFrame(of: editBar)
            frame = PopupPlacement.clamped(
                NSRect(
                    origin: NSPoint(
                        x: screenFrame(of: editBar.move).minX, y: bar.maxY + WidgetSpotPicker.gap),
                    size: size), in: popupBounds)
        }
        picker.panel.present(frame, over: window)
    }

    func followActionPanel() {
        guard !editingWidgets, widgetMenu == nil, actionPanel != nil else { return }
        placeSpotPicker()
    }

    func closeSpotPicker() {
        guard let spotPicker else { return }
        spotPicker.dismiss()
        self.spotPicker = nil
        actionPanel?.onCommand = nil
        showWidgetTools()
    }

    func place(_ id: String, at spot: WidgetGrid.Spot) {
        guard spot != widgetGrid.home(of: id) else {
            closeActions()
            closeSpotPicker()
            return
        }
        guard widgetGrid.accepts(id, at: spot, before: nil) else {
            NSSound.beep()
            return
        }
        closeActions()
        closeSpotPicker()
        report(.moving(widgetGrid.unit(of: id), to: spot, before: nil))
    }

    func pickerCommand(_ selector: Selector, moving id: String) -> Bool {
        guard let picker = spotPicker else { return false }
        switch selector {
        case #selector(NSResponder.moveUp): picker.step(.top)
        case #selector(NSResponder.moveDown): picker.step(.bottom)
        case #selector(NSResponder.moveLeft): picker.step(.left)
        case #selector(NSResponder.moveRight): picker.step(.right)

        case #selector(NSResponder.insertNewline):
            place(id, at: picker.value)

        case #selector(NSResponder.cancelOperation): closeSpotPicker()
        default: return false
        }
        return true
    }
}
