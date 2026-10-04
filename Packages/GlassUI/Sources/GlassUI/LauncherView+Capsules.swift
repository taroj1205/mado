import AppKit

extension LauncherView {
    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 5
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 6

    static func makeActionCapsule(
        _ label: NSTextField, _ divider: NSView, _ toggle: NSView
    ) -> GlassView {
        let enter = FloatingCapsule.keycap("↵")
        let stack = NSStackView(views: [label, enter, divider, toggle])
        stack.spacing = Self.actionGap
        stack.setCustomSpacing(Self.dividerGap, after: enter)
        stack.setCustomSpacing(Self.actionsGap, after: divider)
        return FloatingCapsule.make(
            stack, leading: Self.actionLeading, trailing: Self.actionTrailing)
    }

    static func makeActionsToggle() -> CapsuleButton {
        CapsuleButton("Actions", keys: ["⌘", "K"])
    }

    func showPrimary(_ shown: Bool) {
        guard let stack = actionCapsule.contentView as? NSStackView else { return }
        for view in stack.arrangedSubviews where view !== actionsToggle {
            view.isHidden = !shown
        }
        stack.edgeInsets.left = shown ? Self.actionLeading : Self.actionTrailing
    }

    func showAction(of item: ResultList.Item?) {
        let action =
            editingWidgets
            ? Self.doneTitle
            : selectedPill.map { statusBar.pills[$0].action }
                ?? selectedWidget.map { widgetGrid.shown[$0].action }
                ?? item?.action
        actionLabel.stringValue = action ?? ""
        let primary = action?.isEmpty == false
        showPrimary(primary)
        actionCapsule.isHidden = action == nil
        actionsDivider.isHidden = !primary || editingWidgets
        actionsToggle.isHidden = editingWidgets
        showContext()
    }

    func showContext() {
        statusBar.isHidden = !showsStatusBar
        if statusBar.isHidden {
            closeCustomiser()
        }
        widgetGrid.isHidden = !showsWidgets
        let hintsPreview = (browsing || previewing) && results.selectedItem?.file != nil
        let hint: (text: String?, symbol: String?) =
            if editingWidgets {
                (Self.editHint, Self.editSymbol)
            } else if hintsPreview {
                (Self.previewHint, Self.previewSymbol)
            } else {
                (context, contextSymbol)
            }
        contextPill.show(statusBar.isHidden ? hint.text : nil, symbol: hint.symbol)
    }
}
