import AppKit

extension LauncherView {
    public var pills: [StatusBar.Pill] {
        get { statusBar.pills }
        set {
            let selected = selectedPill.map { statusBar.pills[$0].id }
            statusBar.pills = newValue
            if let index = newValue.firstIndex(where: { $0.id == selected }) {
                selectedPill = index
            } else {
                selectPill(nil)
            }
            statusBar.highlight(selectedPill)
            showAction(of: results.selectedItem)
        }
    }

    var showsStatusBar: Bool {
        onEmptyRootQuery && !pills.isEmpty
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
        showAction(of: results.selectedItem)
    }

    func pressPill(_ index: Int) {
        selectPill(index)
        onPill?(pills[index])
    }

    func moveDown() {
        if !results.selectNext(), showsStatusBar {
            selectPill(0)
        } else {
            selectionMoved()
        }
    }

    func pillCommand(_ selector: Selector, from pill: Int, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveLeft): selectPill(max(pill - 1, 0))

        case #selector(NSResponder.moveRight): selectPill(min(pill + 1, pills.count - 1))

        case #selector(NSResponder.moveUp), #selector(NSResponder.moveDown),
            #selector(NSResponder.cancelOperation):
            selectPill(nil)

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText():
            onPill?(pills[pill])

        default:
            selectPill(nil)
            return false
        }
        return true
    }
}
