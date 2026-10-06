import AppKit

extension LauncherView {
    static let moveToTitle = "Move to…"

    func openWidgetMenu(_ index: Int, at screen: NSPoint) {
        guard !editingWidgets, widgetGrid.shown.indices.contains(index), let window = unsafe window
        else { return }
        closeActions()
        closePreview()
        closeCustomiser()
        selectWidget(index)
        let widget = widgetGrid.shown[index]
        let menu = WidgetMenu()
        menu.onChoose = { [weak self] choice in self?.choose(choice, from: widget) }
        menu.show(menuEntries(for: widget), for: widget.name)
        widgetMenu = menu
        widgetGrid.showMenu(of: index)
        let point = convert(window.convertPoint(fromScreen: screen), from: nil)
        addSubview(menu.glass)
        let left = menu.glass.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: point.x)
        let top = menu.glass.topAnchor.constraint(
            equalTo: topAnchor, constant: bounds.height - point.y)
        for pin in [left, top] {
            pin.priority = .defaultHigh
        }
        NSLayoutConstraint.activate([
            left, top,
            menu.glass.widthAnchor.constraint(equalToConstant: WidgetMenu.width),
            menu.glass.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: Self.capsuleInset),
            menu.glass.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.capsuleInset),
            menu.glass.topAnchor.constraint(
                greaterThanOrEqualTo: topAnchor, constant: Self.capsuleInset),
            menu.glass.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
    }

    func closeWidgetMenu() {
        guard let menu = widgetMenu else { return }
        closeSpotPicker()
        menu.close()
        widgetMenu = nil
        widgetGrid.showMenu(of: nil)
    }

    func widgetMenuCommand(_ selector: Selector) -> Bool {
        guard let menu = widgetMenu else { return false }
        if spotPicker != nil, let widget = selectedWidget {
            return pickerCommand(selector, moving: widgetGrid.shown[widget].id)
        }
        switch selector {
        case #selector(NSResponder.moveUp): menu.moveSelection(by: -1)
        case #selector(NSResponder.moveDown): menu.moveSelection(by: 1)
        case #selector(NSResponder.insertNewline): menu.press()
        case #selector(NSResponder.cancelOperation): closeWidgetMenu()

        default:
            closeWidgetMenu()
            return false
        }
        return true
    }

    func place(_ picker: WidgetSpotPicker, beside menu: WidgetMenu) {
        layoutSubtreeIfNeeded()
        let gap = WidgetSpotPicker.gap
        let room = WidgetSpotPicker.size.width + gap + Self.capsuleInset
        let fitsRight = bounds.width - menu.glass.frame.maxX >= room
        let fitsLeft = menu.glass.frame.minX >= room
        let onLeft = !fitsRight && fitsLeft
        if !fitsRight, !fitsLeft {
            menu.glass.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -room
            ).isActive = true
        }
        let side =
            onLeft
            ? picker.glass.trailingAnchor.constraint(
                equalTo: menu.glass.leadingAnchor, constant: -gap)
            : picker.glass.leadingAnchor.constraint(
                equalTo: menu.glass.trailingAnchor, constant: gap)
        let level = picker.glass.topAnchor.constraint(equalTo: menu.glass.topAnchor)
        level.priority = .defaultHigh
        NSLayoutConstraint.activate([
            side, level,
            picker.glass.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
    }

    func holdWidget(_ index: Int, grabbedAt grab: NSPoint) {
        guard widgetGrid.shown.indices.contains(index) else { return }
        let id = widgetGrid.shown[index].id
        editWidgets()
        guard editingWidgets, let held = widgetGrid.shown.firstIndex(where: { $0.id == id })
        else { return }
        selectWidget(held)
        widgetGrid.pickUp(held, grabbedAt: grab)
    }

    public func addWidgets() {
        editWidgets()
        selectWidget(nil)
    }

    private func choose(_ choice: WidgetMenu.Choice, from widget: WidgetGrid.Widget) {
        if choice != .move {
            closeWidgetMenu()
        }
        switch choice {
        case .open: onWidget?(widget)
        case .move: openSpotPicker(for: widget)
        case .pin: presentPin(for: widget)
        case .edit: editWidgets()
        case .add: addWidgets()
        case .remove: report(.remove(widget.id))
        }
    }

    private func menuEntries(for widget: WidgetGrid.Widget) -> [WidgetMenu.Entry] {
        let pin = pinAction(for: widget).map { action in
            [WidgetMenu.Entry(choice: .pin, title: action.title, detail: action.detail)]
        }
        return [
            .init(choice: .open, title: widget.action),
            .init(
                choice: .move, title: Self.moveToTitle,
                detail: widgetGrid.home(of: widget.id).title),
        ] + (pin ?? []) + [
            .init(choice: .edit, title: Self.editTitle),
            .init(choice: .add, title: Self.addTitle),
            .init(choice: .remove, title: "Remove \(widget.name)"),
        ]
    }
}
