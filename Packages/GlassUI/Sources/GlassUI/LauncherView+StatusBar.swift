import AppKit

extension LauncherView {
    public var pills: [StatusBar.Pill] {
        get { statusBar.pills }
        set {
            statusBar.pills = newValue
            selectPill(nil)
            showContext()
        }
    }

    var showsStatusBar: Bool {
        !scoped && !pills.isEmpty
            && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func selectPill(_ index: Int?) {
        guard index != selectedPill else { return }
        selectedPill = index
        statusBar.highlight(index)
        results.hidesSelection = index != nil
        if index != nil {
            closePreview()
        }
        showAction(of: results.selectedItem)
    }

    func pressPill(_ index: Int) {
        selectPill(selectedPill == index ? nil : index)
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
