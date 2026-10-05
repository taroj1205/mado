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

        case let .step(columns, rows):
            guard let size = widgetGrid.fitted(id, adding: (columns, rows)) else {
                NSSound.beep()
                return
            }
            report(.resize(id, size))
        }
    }
}
