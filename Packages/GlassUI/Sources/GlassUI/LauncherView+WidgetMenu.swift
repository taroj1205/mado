import AppKit

extension LauncherView {
    static let moveToTitle = "Move to…"
    static let sizeTitle = "Size"

    var popupBounds: NSRect {
        guard let window = unsafe window else { return .zero }
        return (window.screen ?? NSScreen.main)?.visibleFrame
            .insetBy(dx: Self.capsuleInset, dy: Self.capsuleInset) ?? window.frame
    }

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
        menu.panel.present(
            PopupPlacement.frame(of: menu.popupSize, hangingFrom: screen, in: popupBounds),
            over: window)
    }

    func screenFrame(of view: NSView) -> NSRect {
        unsafe window?.convertToScreen(view.convert(view.bounds, to: nil)) ?? .zero
    }

    func beside(_ anchor: NSRect, size: NSSize, leftFirst: Bool) -> NSRect {
        PopupPlacement.frame(
            of: size, beside: anchor, gap: WidgetSpotPicker.gap, leftFirst: leftFirst,
            in: popupBounds)
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
        let current = widgetGrid.currentSize(of: widget.id)
        let sizes = sizeOptions(of: widget.id).filter { $0.size != current }
        if let current, !sizes.isEmpty {
            entries.append(.init(choice: .size, title: Self.sizeTitle, detail: current.title))
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
        guard sizeMenu == nil, let menu = widgetMenu, let window = unsafe window else { return }
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
        sizes.panel.present(
            beside(menu.panel.frame, size: sizes.popupSize, leftFirst: false), over: window)
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
