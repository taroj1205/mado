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
            var columns: Int?
            changeWidgets { columns = widgetGrid.finishStretch(id) }
            if let columns {
                report(.resize(id, columns: columns))
            }

        case .step(let change):
            guard let columns = widgetGrid.fitted(id, adding: change) else {
                NSSound.beep()
                return
            }
            report(.resize(id, columns: columns))
        }
    }
}
