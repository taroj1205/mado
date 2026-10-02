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

    public var widgetOverhang: CGFloat { widgetGrid.overhang }

    var showsWidgets: Bool {
        onEmptyRootQuery && !widgetGrid.shown.isEmpty
    }

    private func changeWidgets(_ change: () -> Void) {
        let selected = selectedWidget.map { widgetGrid.shown[$0].id }
        change()
        if let index = widgetGrid.shown.firstIndex(where: { $0.id == selected }) {
            selectedWidget = index
        } else {
            selectWidget(nil)
        }
        widgetGrid.highlight(selectedWidget)
        showAction(of: results.selectedItem)
    }

    func placeWidgets(below separator: NSView) {
        NSLayoutConstraint.activate([
            widgetGrid.leadingAnchor.constraint(equalTo: leadingAnchor),
            widgetGrid.trailingAnchor.constraint(equalTo: trailingAnchor),
            widgetGrid.topAnchor.constraint(equalTo: separator.bottomAnchor),
        ])
        widgetGrid.onPress = { [weak self] index in self?.pressWidget(index) }
    }

    func leavePillsAndWidgets() {
        selectPill(nil)
        selectWidget(nil)
    }

    func selectWidget(_ index: Int?) {
        guard index != selectedWidget else { return }
        if index != nil {
            selectPill(nil)
        }
        selectedWidget = index
        widgetGrid.highlight(index)
        results.hidesSelection = index != nil
        if index != nil {
            closePreview()
        }
        showAction(of: results.selectedItem)
    }

    func pressWidget(_ index: Int) {
        selectWidget(index)
        onWidget?(widgetGrid.shown[index])
    }

    func moveUp() {
        if !results.selectPrevious(), showsWidgets {
            selectWidget(0)
        } else {
            selectionMoved()
        }
    }

    func widgetCommand(_ selector: Selector, from widget: Int, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveLeft): selectWidget(max(widget - 1, 0))

        case #selector(NSResponder.moveRight):
            selectWidget(min(widget + 1, widgetGrid.shown.count - 1))

        case #selector(NSResponder.moveDown):
            results.selectFirst()
            selectWidget(nil)

        case #selector(NSResponder.moveUp): break
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
