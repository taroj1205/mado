import AppKit

extension LauncherView {
    func showActions() {
        guard let item = results.selectedItem, let window = unsafe window else { return }
        closePreview()
        let capsule = window.convertToScreen(actionCapsule.convert(actionCapsule.bounds, to: nil))
        let menu = actionPanel ?? ActionPanel()
        menu.onRun = { [weak self] index in
            self?.closeActions()
            self?.onRun?(item, index)
        }
        menu.onClose = { [weak self] in self?.actionsClosed() }
        actionPanel = menu
        actionsToggle.fillColor = ResultRowView.fill
        menu.show(
            actionTitles?(item) ?? [], for: item.title,
            at: NSPoint(x: capsule.maxX, y: capsule.maxY + Self.capsuleInset), over: window)
        window.makeFirstResponder(nil)
    }

    func closeActions() {
        actionPanel?.close()
    }

    private func actionsClosed() {
        actionsToggle.fillColor = .clear
        unsafe window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(
            location: field.stringValue.utf16.count, length: 0)
    }
}
