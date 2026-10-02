import AppKit

extension LauncherView {
    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 5
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 6
    private static let toggleLeading: CGFloat = 12
    private static let toggleTrailing: CGFloat = 5
    private static let toggleHeight: CGFloat = 30
    private static let toggleRadius: CGFloat = 15
    private static let shortcutGap: CGFloat = 3
    private static let contextLeading: CGFloat = 11
    private static let contextTrailing: CGFloat = 16
    private static let contextIconSize: CGFloat = 17

    static func makeActionCapsule(_ label: NSTextField, _ toggle: NSView) -> GlassView {
        let enter = FloatingCapsule.keycap("↵")
        let divider = FloatingCapsule.divider()
        let stack = NSStackView(views: [label, enter, divider, toggle])
        stack.spacing = Self.actionGap
        stack.setCustomSpacing(Self.dividerGap, after: enter)
        stack.setCustomSpacing(Self.actionsGap, after: divider)
        return FloatingCapsule.make(
            stack, leading: Self.actionLeading, trailing: Self.actionTrailing)
    }

    static func makeActionsToggle() -> NSBox {
        let actions = FloatingCapsule.label(weight: .medium, color: .labelColor)
        actions.stringValue = "Actions"
        let command = FloatingCapsule.keycap("⌘")
        let stack = NSStackView(views: [actions, command, FloatingCapsule.keycap("K")])
        stack.spacing = Self.actionGap
        stack.setCustomSpacing(Self.shortcutGap, after: command)
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.toggleLeading, bottom: 0, right: Self.toggleTrailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = Self.toggleRadius
        box.fillColor = .clear
        box.contentViewMargins = .zero
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: Self.toggleHeight),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    static func makeContextCapsule(_ label: NSTextField) -> GlassView {
        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "chevron.forward.circle.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.contextIconSize, weight: .semibold
        )
        .applying(.init(paletteColors: [.white, .controlAccentColor]))
        let stack = NSStackView(views: [icon, label])
        stack.spacing = Self.actionGap
        return FloatingCapsule.make(
            stack, leading: Self.contextLeading, trailing: Self.contextTrailing)
    }
}
