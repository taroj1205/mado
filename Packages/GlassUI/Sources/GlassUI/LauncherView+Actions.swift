import AppKit

extension LauncherView {
    func showActions() {
        guard let item = results.selectedItem else { return }
        closePreview()
        let menu = actionPanel ?? ActionPanel()
        menu.onRun = { [weak self] index in
            self?.closeActions()
            self?.onRun?(item, index)
        }
        menu.onClose = { [weak self] in self?.actionsClosed() }
        actionPanel = menu
        actionsToggle.fillColor = ResultRowView.fill
        menu.show(
            actionTitles?(item) ?? [], for: item.title, above: actionCapsule,
            gap: Self.capsuleInset)
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
