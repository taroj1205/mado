import AppKit

extension LauncherView {
    var customising: Bool { customiser?.isVisible == true }

    func toggleCustomiser() {
        if customising {
            closeCustomiser()
        } else {
            openCustomiser()
        }
    }

    func closeCustomiser() {
        guard let customiser, customiser.isVisible else { return }
        customiser.glass.removeFromSuperview()
        statusBar.customise.isOpen = false
    }

    func closeCustomiser(unlessAt point: NSPoint) {
        guard let customiser, customiser.isVisible else { return }
        let views: [NSView] = [customiser.glass, statusBar.customise]
        if !views.contains(where: { $0.convert($0.bounds, to: nil).contains(point) }) {
            closeCustomiser()
        }
    }

    func refreshCustomiser() {
        guard let customiser, customiser.isVisible else { return }
        let shown = statusBar.pills
        customiser.show(shown, more: pills.filter { pill in !shown.contains { $0.id == pill.id } })
    }

    func movePill(_ id: String, before target: String?) {
        editStatusLayout { layout, pills in layout.move(id, before: target, among: pills) }
    }

    private func openCustomiser() {
        leavePillsAndWidgets()
        closePreview()
        closeActions()
        let panel = customiser ?? makeCustomiser()
        customiser = panel
        addSubview(panel.glass)
        let lift = Self.capsuleInset + FloatingCapsule.height + StatusBarCustomiser.gap
        NSLayoutConstraint.activate([
            panel.glass.widthAnchor.constraint(equalToConstant: StatusBarCustomiser.width),
            panel.glass.heightAnchor.constraint(equalToConstant: StatusBarCustomiser.height),
            panel.glass.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            panel.glass.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -lift),
        ])
        statusBar.customise.isOpen = true
        refreshCustomiser()
    }

    private func makeCustomiser() -> StatusBarCustomiser {
        let panel = StatusBarCustomiser()
        panel.onToggle = { [weak self] id, isShown in
            self?.editStatusLayout { layout, pills in layout.show(id, isShown, among: pills) }
        }
        panel.onMove = { [weak self] id, target in self?.movePill(id, before: target) }
        panel.onReset = { [weak self] in
            self?.editStatusLayout { layout, _ in layout = StatusBarLayout() }
        }
        panel.onDone = { [weak self] in self?.closeCustomiser() }
        return panel
    }

    private func editStatusLayout(
        _ edit: (inout StatusBarLayout, [StatusBar.Pill]) -> Void
    ) {
        var layout = statusLayout
        edit(&layout, pills)
        guard layout != statusLayout else { return }
        statusLayout = layout
        onStatusLayout?(layout)
    }
}
