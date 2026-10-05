import AppKit

extension LauncherView {
    public enum CapsuleSlot: Equatable, Sendable {
        case primary
        case keyed([String])
        case actions

        public static let standard: [Self] = [.primary, .actions]
    }

    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 5
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 6

    static func makeActionCapsule() -> GlassView {
        let stack = NSStackView()
        stack.spacing = Self.actionGap
        return FloatingCapsule.make(
            stack, leading: Self.actionLeading, trailing: Self.actionTrailing)
    }

    static func makeActionsToggle() -> CapsuleButton {
        CapsuleButton("Actions", keys: ["⌘", "K"])
    }

    func showAction(of item: ResultList.Item?) {
        let action =
            editingWidgets
            ? nil
            : selectedPill.map { statusBar.pills[$0].action }
                ?? selectedWidget.map { widgetGrid.shown[$0].action }
                ?? item?.action
        actionLabel.stringValue = action ?? ""
        let slots =
            selectedPill != nil || selectedWidget != nil ? CapsuleSlot.standard : capsuleSlots
        let groups = slots.map { capsuleGroup($0, primary: action, for: item) }
        arrangeCapsule(groups)
        actionCapsule.isHidden = action == nil || groups.allSatisfy(\.isEmpty)
        showContext()
    }

    private func capsuleGroup(
        _ slot: CapsuleSlot, primary: String?, for item: ResultList.Item?
    ) -> [NSView] {
        switch slot {
        case .primary:
            return primary?.isEmpty == false ? [actionLabel, actionKeycap] : []

        case .keyed(let keys):
            guard let item, let action = actions?(item).first(where: { $0.keys == keys }) else {
                return []
            }
            let button = CapsuleButton(action.title, keys: keys)
            button.onPress = { [weak self] in self?.run(keyed: keys) }
            return [button]

        case .actions:
            return [actionsToggle]
        }
    }

    private func arrangeCapsule(_ groups: [[NSView]]) {
        guard let stack = actionCapsule.contentView as? NSStackView else { return }
        stack.setViews([], in: .leading)
        for (index, group) in groups.filter({ !$0.isEmpty }).enumerated() {
            if index > 0, let last = stack.arrangedSubviews.last {
                let divider = FloatingCapsule.divider()
                stack.setCustomSpacing(
                    last === actionKeycap ? Self.dividerGap : Self.actionsGap, after: last)
                stack.addArrangedSubview(divider)
                stack.setCustomSpacing(Self.actionsGap, after: divider)
            }
            group.forEach(stack.addArrangedSubview)
        }
        stack.edgeInsets.left =
            stack.arrangedSubviews.first === actionLabel ? Self.actionLeading : Self.actionTrailing
    }

    func showContext() {
        statusBar.isHidden = !showsStatusBar
        if statusBar.isHidden {
            closeCustomiser()
        }
        widgetGrid.isHidden = !showsWidgets
        showWidgetTools()
        if editingWidgets {
            contextPill.show(nil as String?, symbol: nil)
            return
        }
        if let selected = gridContext() {
            contextPill.show(selected.text, glyph: selected.glyph)
            return
        }
        let hintsPreview = (browsing || previewing) && selectedItem?.file != nil
        let hint: (text: String?, symbol: String?) =
            if hintsPreview {
                (Self.previewHint, Self.previewSymbol)
            } else {
                (context, contextSymbol)
            }
        contextPill.show(statusBar.isHidden ? hint.text : nil, symbol: hint.symbol)
    }
}
