import AppKit

enum MenuBarPanelStyle {
    static let width: CGFloat = 320
    static let padding: CGFloat = 14
    static let spacing: CGFloat = 10
    static let captionSize: CGFloat = 11.5
    static let titleSize: CGFloat = 14
    static let detailSize: CGFloat = 12.5
    static let infoSpacing: CGFloat = 4
    static let inner = width - padding - padding

    @MainActor
    static func install(_ stack: NSStackView, in view: NSView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(
            top: padding, left: padding, bottom: padding, right: padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.widthAnchor.constraint(equalToConstant: width),
        ])
    }

    @MainActor
    static func addFullWidth(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: inner).isActive = true
    }

    @MainActor
    static func addRule(to stack: NSStackView) {
        let rule = NSBox()
        rule.boxType = .separator
        addFullWidth(rule, to: stack)
    }

    @MainActor
    static func label(
        _ size: CGFloat, weight: NSFont.Weight, secondary: Bool
    ) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = secondary ? .secondaryLabelColor : .labelColor
        field.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    @MainActor
    static func info(_ views: [NSView]) -> NSStackView {
        let info = NSStackView(views: views)
        info.orientation = .vertical
        info.alignment = .leading
        info.spacing = infoSpacing
        return info
    }

    @MainActor
    static func present(
        _ panel: some MenuBarPanel, below button: NSStatusBarButton,
        delegate: any NSPopoverDelegate
    ) -> NSPopover {
        let controller = NSViewController()
        controller.view = panel
        controller.preferredContentSize = panel.frame.size
        panel.onResize = { [weak controller] size in controller?.preferredContentSize = size }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = delegate
        popover.contentViewController = controller
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        unsafe panel.window?.makeKey()
        return popover
    }
}
