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
        let entries: [(action: Action, run: () -> Void)] = [
            (
                Action(widget.action, keys: Action.primaryKeys),
                { [weak self] in self?.onWidget?(widget) }
            ),
            (move, { [weak self] in self?.openSpotPicker(for: widget) }),
            (Action(Self.editTitle), { [weak self] in self?.editWidgets() }),
            (Action(Self.addTitle), { [weak self] in self?.addWidgets() }),
            (remove, { [weak self] in self?.report(.remove(widget.id)) }),
        ]
        present(entries.map(\.action), for: widget.name) { index in entries[index].run() }
        actionPanel?.onOpen = { index in entries[index].run() }
    }

    func openSpotPicker(for widget: WidgetGrid.Widget) {
        let panel = editingWidgets || widgetMenu != nil ? nil : actionPanel
        guard spotPicker == nil, editingWidgets || widgetMenu != nil || panel != nil else {
            return
        }
        let picker = WidgetSpotPicker(moving: widget.name, from: widgetGrid.home(of: widget.id))
        picker.onPick = { [weak self] spot in self?.place(widget.id, at: spot) }
        addSubview(picker.glass)
        NSLayoutConstraint.activate([
            picker.glass.widthAnchor.constraint(equalToConstant: WidgetSpotPicker.size.width),
            picker.glass.heightAnchor.constraint(equalToConstant: WidgetSpotPicker.size.height),
        ])
        spotPicker = picker
        if let widgetMenu {
            place(picker, beside: widgetMenu)
            return
        }
        guard let panel else {
            NSLayoutConstraint.activate([
                picker.glass.leadingAnchor.constraint(equalTo: editBar.move.leadingAnchor),
                picker.glass.bottomAnchor.constraint(
                    equalTo: editBar.topAnchor, constant: -WidgetSpotPicker.gap),
            ])
            showWidgetTools()
            return
        }
        NSLayoutConstraint.activate([
            picker.glass.trailingAnchor.constraint(
                equalTo: panel.glass.leadingAnchor, constant: -WidgetSpotPicker.gap),
            picker.glass.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        let level = picker.glass.topAnchor.constraint(equalTo: panel.glass.topAnchor)
        level.priority = .defaultHigh
        level.isActive = true
        panel.onCommand = { [weak self] selector in
            self?.pickerCommand(selector, moving: widget.id) ?? false
        }
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
