import AppKit

extension LauncherView {
    public enum CapsuleSlot: Equatable, Sendable {
        case primary
        case keyed([String])
        case actions

        public static let standard: [Self] = [.primary, .actions]
    }

    struct ArrangedCapsule: Equatable {
        let slots: [CapsuleSlot]
        let tokens: [[AnyHashable]]
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

    private static func token(of view: NSView) -> AnyHashable {
        (view as? CapsuleButton).map { AnyHashable($0.label.stringValue) }
            ?? AnyHashable(ObjectIdentifier(view))
    }

    static func makeResultsFade() -> CAGradientLayer {
        let fadeMiddle: CGFloat = 0.5
        let fade = CAGradientLayer()
        fade.startPoint = CGPoint(x: fadeMiddle, y: 0)
        fade.endPoint = CGPoint(x: fadeMiddle, y: 1)
        fade.colors = [NSColor.black, .black, .clear, .clear].map(\.cgColor)
        return fade
    }

    func fadeResultsBehindCapsules() {
        let height = max(results.bounds.height, 1)
        let solid = max(height - results.contentInsets.bottom, 0) / height
        let clear = min(solid + Self.capsuleInset / height, 1)
        CATransaction.quietly {
            resultsFade.frame = results.bounds
            resultsFade.locations = [0, solid, clear, 1].map { .init(value: $0) }
        }
    }

    func placeCapsules() {
        addSubview(contextPill)
        addSubview(statusBar)
        addSubview(actionCapsule)
        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.capsuleInset),
            statusBar.trailingAnchor.constraint(
                lessThanOrEqualTo: actionCapsule.leadingAnchor, constant: -Self.capsuleInset),
            statusBar.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor),
            contextPill.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            contextPill.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor),
            actionCapsule.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.capsuleInset),
            actionCapsule.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        results.contentInsets.bottom =
            Self.capsuleInset + FloatingCapsule.height + Self.capsuleInset
        results.wantsLayer = true
        results.layer?.mask = resultsFade
        results.onSelect = { [weak self] item in self?.selectionChanged(to: item) }
        results.onMove = { [weak self] in self?.selectionMoved() }
        results.onPick = { [weak self] query in self?.replaceQuery(with: query) }
        calendarPane.grid.onPick = { [weak self] query in self?.replaceQuery(with: query) }
        actionsToggle.onPress = { [weak self] in self?.toggleActions() }
        statusBar.onPress = { [weak self] index in self?.pressPill(index) }
        statusBar.onMove = { [weak self] id, target in self?.movePill(id, before: target) }
        statusBar.customise.onPress = { [weak self] in self?.toggleCustomiser() }
        field.setAccessibilitySharedFocusElements([results.table, emojiGrid.collection])
        showAction(of: nil)
    }

    func showAction(of item: ResultList.Item?) {
        let action =
            editingWidgets
            ? nil
            : selectedPill.map { statusBar.pills[$0].action }
                ?? selectedWidget.map { widgetGrid.shown[$0].action }
                ?? mergePane.merge?.action ?? item?.action
        actionLabel.stringValue = action ?? ""
        let slots =
            selectedPill != nil || selectedWidget != nil ? CapsuleSlot.standard : capsuleSlots
        let groups = slots.map { capsuleGroup($0, primary: action, for: item) }
        arrangeCapsule(groups, for: slots)
        actionCapsule.isHidden = action == nil || groups.allSatisfy(\.isEmpty) || showsLyrics
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

    private func arrangeCapsule(_ groups: [[NSView]], for slots: [CapsuleSlot]) {
        let next = ArrangedCapsule(slots: slots, tokens: groups.map { $0.map(Self.token(of:)) })
        guard next != arrangedCapsule, let stack = actionCapsule.contentView as? NSStackView
        else { return }
        arrangedCapsule = next
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
        if editingWidgets || showsLyrics {
            contextPill.show(nil as String?, symbol: nil)
            return
        }
        if let selected = gridContext() {
            contextPill.show(selected.text, glyph: selected.glyph)
            return
        }
        if !results.checked.isEmpty {
            let selected = StatusPill.styled(bold: "\(results.checked.count)", rest: " selected")
            contextPill.show(selected, symbol: "checkmark")
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
