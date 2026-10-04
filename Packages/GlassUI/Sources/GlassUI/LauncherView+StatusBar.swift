import AppKit

extension LauncherView {
    var showsStatusBar: Bool {
        homeShown && !pills.isEmpty && !editingWidgets
    }

    func arrangePills() {
        let selected = selectedPill.map { statusBar.pills[$0].id }
        statusBar.pills = statusLayout.arrange(pills)
        if let index = statusBar.pills.firstIndex(where: { $0.id == selected }) {
            selectedPill = index
        } else {
            selectPill(nil)
        }
        statusBar.highlight(selectedPill)
        showAction(of: selectedItem)
        refreshCustomiser()
    }

    func selectPill(_ index: Int?) {
        guard index != selectedPill else { return }
        if index != nil {
            selectWidget(nil)
        }
        selectedPill = index
        statusBar.highlight(index)
        results.hidesSelection = index != nil
        if index != nil {
            closePreview()
        }
        showAction(of: selectedItem)
    }

    func pressPill(_ index: Int) {
        selectPill(index)
        onPill?(statusBar.pills[index])
    }

    func moveDown() {
        if !results.selectNext(), showsStatusBar, !statusBar.pills.isEmpty, !isKeyRepeat() {
            selectPill(0)
        } else {
            selectionMoved()
        }
    }

    func pillCommand(_ selector: Selector, from pill: Int, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveLeft): selectPill(max(pill - 1, 0))

        case #selector(NSResponder.moveRight): selectPill(min(pill + 1, statusBar.pills.count - 1))
        case #selector(NSResponder.moveDown) where isKeyRepeat(): break

        case #selector(NSResponder.moveUp), #selector(NSResponder.moveDown),
            #selector(NSResponder.cancelOperation):
            selectPill(nil)

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText():
            onPill?(statusBar.pills[pill])

        default:
            selectPill(nil)
            return false
        }
        return true
    }
}
