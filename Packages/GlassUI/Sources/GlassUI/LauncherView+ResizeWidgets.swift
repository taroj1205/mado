import AppKit

extension LauncherView {
    func resizeWidget(_ index: Int, _ resize: WidgetTile.Resize) {
        guard widgetGrid.shown.indices.contains(index) else { return }
        let id = widgetGrid.shown[index].id
        switch resize {
        case .drag(let distance):
            if selectedWidget != index {
                selectWidget(index)
            }
            changeWidgets { widgetGrid.stretch(id, by: distance) }

        case .drop:
            var size: WidgetGrid.Size?
            changeWidgets { size = widgetGrid.finishStretch(id) }
            if let size {
                report(.resize(id, size))
            }

        case let .step(columns, rows): stepWidgetSize(id, columns: columns, rows: rows)
        case .size(let size): setWidgetSize(id, to: size)
        }
    }

    func sizeOptions(of id: String) -> [WidgetSizeSwitch.Option] {
        let rail = widgetGrid.home(of: id).side.isRail
        return widgetGrid.options(for: id).map { size in
            .init(size: size, title: rail ? size.rowsTitle : size.name ?? size.dimensions)
        }
    }

    func subject(of widget: WidgetGrid.Widget) -> WidgetEditBar.Subject {
        .init(
            name: widget.name, spot: widgetGrid.home(of: widget.id),
            sizes: sizeOptions(of: widget.id),
            current: widgetGrid.currentSize(of: widget.id) ?? widget.size)
    }

    func connectSizeSwitch() {
        editBar.onSize = { [weak self] size in
            guard let self, let selectedWidget else { return }
            resizeWidget(selectedWidget, .size(size))
        }
    }

    private func stepWidgetSize(_ id: String, columns: Int, rows: Int) {
        guard let size = widgetGrid.fitted(id, adding: (columns, rows)) else {
            NSSound.beep()
            return
        }
        report(.resize(id, size))
    }

    private func setWidgetSize(_ id: String, to size: WidgetGrid.Size) {
        if size != widgetGrid.currentSize(of: id) {
            report(.resize(id, size))
        }
    }
}
