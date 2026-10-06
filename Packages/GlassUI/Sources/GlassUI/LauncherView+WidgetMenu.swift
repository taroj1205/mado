import AppKit

extension LauncherView {
    static let moveToTitle = "Move to…"
    static let sizeTitle = "Size"

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
        closeSizeMenu()
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
        if let sizes = sizeMenu {
            return sizeMenuCommand(selector, in: sizes)
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

    func place(_ glass: GlassView, width: CGFloat, beside menu: WidgetMenu) {
        layoutSubtreeIfNeeded()
        let gap = WidgetSpotPicker.gap
        let room = width + gap + Self.capsuleInset
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
            ? glass.trailingAnchor.constraint(equalTo: menu.glass.leadingAnchor, constant: -gap)
            : glass.leadingAnchor.constraint(equalTo: menu.glass.trailingAnchor, constant: gap)
        let level = glass.topAnchor.constraint(equalTo: menu.glass.topAnchor)
        level.priority = .defaultHigh
        NSLayoutConstraint.activate([
            side, level,
            glass.bottomAnchor.constraint(
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
        if choice != .move, choice != .size {
            closeWidgetMenu()
        }
        switch choice {
        case .open: onWidget?(widget)
        case .move: openSpotPicker(for: widget)
        case .size: openSizeMenu(for: widget)
        case .pin: presentPin(for: widget)
        case .edit: editWidgets()
        case .add: addWidgets()
        case .remove: report(.remove(widget.id))
        }
    }

    private func menuEntries(for widget: WidgetGrid.Widget) -> [WidgetMenu.Entry] {
        var entries: [WidgetMenu.Entry] = [
            .init(choice: .open, title: widget.action),
            .init(
                choice: .move, title: Self.moveToTitle,
                detail: widgetGrid.home(of: widget.id).title),
        ]
        if sizeOptions(of: widget.id).count > 1, let size = widgetGrid.currentSize(of: widget.id) {
            entries.append(.init(choice: .size, title: Self.sizeTitle, detail: size.title))
        }
        if let pin = pinAction(for: widget) {
            entries.append(.init(choice: .pin, title: pin.title, detail: pin.detail))
        }
        return entries + [
            .init(choice: .edit, title: Self.editTitle),
            .init(choice: .add, title: Self.addTitle),
            .init(choice: .remove, title: "Remove \(widget.name)"),
        ]
    }
}

extension LauncherView {
    func openSizeMenu(for widget: WidgetGrid.Widget) {
        guard sizeMenu == nil, let menu = widgetMenu else { return }
        closeSpotPicker()
        let current = widgetGrid.currentSize(of: widget.id)
        let sizes = WidgetMenu()
        sizes.onSize = { [weak self] size in
            self?.closeWidgetMenu()
            if let index = self?.widgetGrid.shown.firstIndex(where: { $0.id == widget.id }) {
                self?.resizeWidget(index, .size(size))
            }
        }
        sizes.show(
            sizeOptions(of: widget.id).map { option in
                .init(
                    choice: .size, title: option.title, detail: option.size.dimensions,
                    size: option.size, checked: option.size == current)
            }, for: Self.sizeTitle)
        sizeMenu = sizes
        addSubview(sizes.glass)
        NSLayoutConstraint.activate([
            sizes.glass.widthAnchor.constraint(equalToConstant: WidgetMenu.width)
        ])
        place(sizes.glass, width: WidgetMenu.width, beside: menu)
    }

    func closeSizeMenu() {
        sizeMenu?.close()
        sizeMenu = nil
    }

    func sizeMenuCommand(_ selector: Selector, in menu: WidgetMenu) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp): menu.moveSelection(by: -1)
        case #selector(NSResponder.moveDown): menu.moveSelection(by: 1)
        case #selector(NSResponder.insertNewline): menu.press()

        case #selector(NSResponder.cancelOperation), #selector(NSResponder.moveLeft),
            #selector(NSResponder.moveRight):
            closeSizeMenu()

        default:
            closeWidgetMenu()
            return false
        }
        return true
    }
}
