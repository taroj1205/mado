import AppKit

extension LauncherView {
    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 5
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 6

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
}
