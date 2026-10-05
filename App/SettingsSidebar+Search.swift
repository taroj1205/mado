import AppKit

extension SettingsSidebar: NSSearchFieldDelegate {
    func controlTextDidChange(_: Notification) {
        update()
    }

    func controlTextDidEndEditing(_: Notification) {
        fieldFocused = false
        if query.isEmpty {
            update()
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy command: Selector) -> Bool {
        switch command {
        case #selector(NSResponder.moveDown(_:)):
            move(by: 1)

        case #selector(NSResponder.moveUp(_:)):
            move(by: -1)

        case #selector(NSResponder.insertNewline(_:)):
            go(at: table.selectedRow)

        case #selector(NSResponder.cancelOperation(_:)):
            delegate?.sidebarEndedSearch()

        case #selector(NSResponder.deleteBackward(_:)):
            return forgetSelectedRecent()

        default:
            return false
        }
        return true
    }
}
