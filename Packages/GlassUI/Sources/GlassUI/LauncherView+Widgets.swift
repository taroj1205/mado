public import AppKit

extension LauncherView {
    public var widgets: [WidgetGrid.Widget] {
        get { widgetGrid.widgets }
        set { changeWidgets { widgetGrid.widgets = newValue } }
    }

    public var widgetLayout: WidgetGrid.Layout? {
        get { widgetGrid.tileLayout }
        set { changeWidgets { widgetGrid.tileLayout = newValue } }
    }

    public var opensWidgetsOnSingleClick: Bool {
        get { widgetGrid.opensOnSingleClick }
        set { widgetGrid.opensOnSingleClick = newValue }
    }

    public var widgetSpots: [String: WidgetGrid.Spot] {
        get { widgetGrid.spots }
        set { changeWidgets { widgetGrid.spots = newValue } }
    }

    public var widgetSizes: [String: WidgetGrid.Size] {
        get { widgetGrid.sizes }
        set { changeWidgets { widgetGrid.sizes = newValue } }
    }

    public var widgetCatalogue: [WidgetGallery.Card] {
        get { gallery.catalogue }
        set { gallery.catalogue = newValue }
    }

    public var widgetPreviews: [WidgetGrid.Widget] {
        get { gallery.previews }
        set {
            gallery.previews = newValue
            showVerse(among: newValue)
        }
    }

    public var widgetsFillPanel: Bool { widgetGrid.fillsPanel }

    public var widgetShift: CGFloat { widgetGrid.overhang - widgetGrid.underhang }

    public var widgetsBottom: CGFloat { widgetGrid.convert(widgetGrid.bounds, to: nil).minY }

    var showsWidgets: Bool {
        homeShown && (editingWidgets || !widgetGrid.shown.isEmpty)
    }

    private static func page(for key: NSEvent.SpecialKey?) -> WidgetGrid.Page? {
        switch key {
        case .leftArrow: .previous
        case .rightArrow: .next
        default: nil
        }
    }

    func changeWidgets(_ change: () -> Void) {
        let selected = selectedWidget.map { widgetGrid.shown[$0].id }
        change()
        if let index = widgetGrid.shown.firstIndex(where: { $0.id == selected }) {
            selectedWidget = index
            widgetGrid.picked = widgetGrid.picked.filter { id in
                widgetGrid.shown.contains { $0.id == id }
            }
        } else {
            selectWidget(nil)
        }
        widgetGrid.highlight(selectedWidget)
        showAction(of: selectedItem)
    }

    func placeWidgets(below separator: NSView) {
        NSLayoutConstraint.activate([
            widgetGrid.leadingAnchor.constraint(equalTo: leadingAnchor),
            widgetGrid.trailingAnchor.constraint(equalTo: trailingAnchor),
            widgetGrid.topAnchor.constraint(equalTo: separator.bottomAnchor),
        ])
        widgetGrid.onPress = { [weak self] index in self?.pressWidget(index) }
        widgetGrid.onMenu = { [weak self] index, point in self?.openWidgetMenu(index, at: point) }
        widgetGrid.onHold = { [weak self] index, grab in self?.holdWidget(index, grabbedAt: grab) }
        widgetGrid.onOpen = { [weak self] index in self?.openWidget(index) }
        widgetGrid.onExtend = { [weak self] index in self?.extendWidgetSelection(index) }
        widgetGrid.onSkip = { [weak self] index, skip in self?.skipTrack(index, skip) }
        widgetGrid.onDay = { [weak self] query in
            self?.closeWidgetMenu()
            self?.replaceQuery(with: query)
        }
        widgetGrid.onPage = { [weak self] index, page in self?.pageMonth(index, page) }
        widgetGrid.onSeek = { [weak self] index, line in
            self?.closeWidgetMenu()
            self?.selectWidget(index)
            self?.onSeek?(line)
        }
        widgetGrid.onRemove = { [weak self] index in self?.removeWidget(index) }
        widgetGrid.onPinOff = { [weak self] in self?.pinOffPanel() }
        widgetGrid.onResize = { [weak self] index, resize in self?.resizeWidget(index, resize) }
        placeEditing()
    }

    func leavePillsAndWidgets() {
        selectPill(nil)
        selectWidget(nil)
    }

    func selectWidget(_ index: Int?) {
        let picked = !widgetGrid.picked.isEmpty
        widgetGrid.picked = []
        guard index != selectedWidget else {
            if picked {
                widgetGrid.highlight(index)
                showAction(of: selectedItem)
            }
            return
        }
        closeWidgetMenu()
        if editingWidgets {
            closeSpotPicker()
        }
        if index != nil {
            selectPill(nil)
        }
        selectedWidget = index
        widgetGrid.highlight(index)
        results.hidesSelection = index != nil || editingWidgets
        if index != nil {
            closePreview()
        }
        showAction(of: selectedItem)
    }

    func skipTrack(_ index: Int, _ skip: WidgetGrid.Skip) {
        closeWidgetMenu()
        selectWidget(index)
        widgetGrid.tiles[index].track.pulse(skip)
        onSkip?(skip)
    }

    func pageMonth(_ index: Int, _ page: WidgetGrid.Page) {
        closeWidgetMenu()
        selectWidget(index)
        onPage?(page)
    }

    func handleModifiedKey(_ event: NSEvent) -> Bool {
        guard !editingWidgets, !event.modifierFlags.isDisjoint(with: Self.modifierKeys) else {
            return false
        }
        let command = event.modifierFlags.intersection(Self.modifierKeys) == .command
        if command, selectedWidget != nil, event.charactersIgnoringModifiers == "k" {
            showActions()
            return true
        }
        if command, let widget = selectedWidget, widgetGrid.shown[widget].track != nil {
            switch event.specialKey {
            case .leftArrow:
                skipTrack(widget, .previous)
                return true

            case .rightArrow:
                skipTrack(widget, .next)
                return true

            default: break
            }
        }
        if command, let widget = selectedWidget, widgetGrid.shown[widget].isMonth {
            if let page = Self.page(for: event.specialKey) {
                pageMonth(widget, page)
                return true
            }
        }
        leavePillsAndWidgets()
        return false
    }

    func pressWidget(_ index: Int) {
        closeWidgetMenu()
        selectWidget(index)
    }

    func openWidget(_ index: Int) {
        guard !editingWidgets else { return }
        let widget = widgetGrid.shown[index]
        if widget.isPlayer {
            onOpenPlayer?()
        } else {
            onWidget?(widget)
        }
    }

    func moveUp() {
        if !results.selectPrevious(), showsWidgets, !isKeyRepeat() {
            selectWidget(0)
        } else {
            selectionMoved()
        }
    }

    func widgetCommand(_ selector: Selector, from widget: Int, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveLeft): stepWidget(.left)
        case #selector(NSResponder.moveRight): stepWidget(.right)
        case #selector(NSResponder.moveUp): stepWidget(.top)

        case #selector(NSResponder.moveDown):
            if let below = widgetGrid.neighbour(of: widget, toward: .bottom) {
                selectWidget(below)
            } else {
                results.selectFirst()
                selectWidget(nil)
            }

        case #selector(NSResponder.cancelOperation): selectWidget(nil)

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText():
            onWidget?(widgetGrid.shown[widget])

        default:
            selectWidget(nil)
            return false
        }
        return true
    }
}
