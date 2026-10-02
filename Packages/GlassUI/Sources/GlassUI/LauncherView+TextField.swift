public import AppKit

extension LauncherView: NSTextFieldDelegate {
    public func controlTextDidChange(_: Notification) {
        endBrowsing()
        onQuery?(field.stringValue)
    }

    public func control(
        _: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        if let pill = selectedPill { return pillCommand(selector, from: pill, in: textView) }
        return fieldCommand(selector, in: textView)
    }

    private func fieldCommand(_ selector: Selector, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp):
            results.selectPrevious()
            selectionMoved()

        case #selector(NSResponder.moveDown): moveDown()

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText(): run(0)
        case #selector(NSResponder.cancelOperation) where previewing: closePreview()
        case #selector(NSResponder.cancelOperation) where scoped: leave()
        case #selector(NSResponder.cancelOperation): onCancel?()
        case #selector(NSResponder.deleteBackward) where scoped && textView.string.isEmpty: leave()

        default:
            endBrowsing()
            return false
        }
        return true
    }
}
