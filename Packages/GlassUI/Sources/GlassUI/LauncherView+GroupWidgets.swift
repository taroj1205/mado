import AppKit

extension LauncherView {
    var chosenWidgets: [String] {
        guard let selectedWidget else { return [] }
        return [widgetGrid.shown[selectedWidget].id] + widgetGrid.picked
    }

    func extendWidgetSelection(_ index: Int) {
        guard editingWidgets, widgetGrid.shown.indices.contains(index) else { return }
        guard selectedWidget != nil else {
            selectWidget(index)
            return
        }
        let id = widgetGrid.shown[index].id
        var chosen = chosenWidgets
        if let position = chosen.firstIndex(of: id) {
            chosen.remove(at: position)
        } else {
            chosen.append(id)
        }
        choose(chosen)
    }

    func extendWidgetSelection(toward heading: WidgetGrid.Heading) {
        let shown = widgetGrid.shown.map(\.id)
        let chosen = chosenWidgets
        guard let from = chosen.last.flatMap(shown.firstIndex(of:)),
            let next = widgetGrid.neighbour(of: from, toward: heading)
        else {
            NSSound.beep()
            return
        }
        if chosen.dropLast().last == shown[next] {
            choose(chosen.dropLast())
        } else if !chosen.contains(shown[next]) {
            choose(chosen + [shown[next]])
        }
    }

    func groupWidgets() {
        let chosen = Set(chosenWidgets.flatMap(widgetGrid.unit))
        let ids = widgetGrid.shown.map(\.id).filter(chosen.contains)
        guard editingWidgets, chosenWidgets.count > 1 else {
            NSSound.beep()
            return
        }
        let homes = chosenWidgets.map(widgetGrid.home)
        let undoable = widgetNote?.undoable == true
        guard let anchor = homes.first(where: { $0.side != .panel }) else {
            note("Move one of them out of the panel to group them", undoable: undoable)
            return
        }
        guard Set(ids.map(widgetGrid.home)).count > 1 else {
            note("They’re already a group", undoable: undoable)
            return
        }
        guard let spot = widgetGrid.room(for: ids, near: anchor) else {
            NSSound.beep()
            note("No room to put them together", undoable: undoable)
            return
        }
        let primary = chosenWidgets.first
        widgetGrid.picked = []
        report(.group(ids, spot, before: nil))
        reselect(primary)
    }

    func ungroupWidget() {
        guard editingWidgets, let selectedWidget else { return }
        let id = widgetGrid.shown[selectedWidget].id
        guard widgetGrid.unit(of: id).count > 1 else {
            NSSound.beep()
            return
        }
        let spots = widgetGrid.spread(id)
        guard !spots.isEmpty else {
            NSSound.beep()
            note("No room to split this group", undoable: widgetNote?.undoable == true)
            return
        }
        report(.spread(spots))
        reselect(id)
    }

    private func reselect(_ id: String?) {
        if let index = widgetGrid.shown.firstIndex(where: { $0.id == id }) {
            selectWidget(index)
        }
    }

    private func choose(_ chosen: some Collection<String>) {
        let shown = widgetGrid.shown.map(\.id)
        selectWidget(chosen.first.flatMap(shown.firstIndex(of:)))
        widgetGrid.picked = Array(chosen.dropFirst())
        widgetGrid.highlight(selectedWidget)
        showWidgetTools()
    }
}
