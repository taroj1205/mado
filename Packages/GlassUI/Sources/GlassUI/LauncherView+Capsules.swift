import AppKit

extension LauncherView {
    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 5
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 6
    private static let contextLeading: CGFloat = 11
    private static let contextTrailing: CGFloat = 16
    private static let contextIconSize: CGFloat = 17
    private static let badgeSize: CGFloat = 18
    private static let badgeGlyphSize: CGFloat = 10
    private static let half: CGFloat = 0.5
    private static let contextChevron = "chevron.forward.circle.fill"

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

    static func makeContextIcon() -> NSImageView {
        let icon = NSImageView()
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.contextIconSize, weight: .semibold
        )
        .applying(.init(paletteColors: [.white, .controlAccentColor]))
        icon.image = contextImage(nil)
        return icon
    }

    static func contextImage(_ symbol: String?) -> NSImage? {
        guard let symbol else {
            return NSImage(systemSymbolName: Self.contextChevron, accessibilityDescription: nil)
        }
        let style = NSImage.SymbolConfiguration(pointSize: Self.badgeGlyphSize, weight: .bold)
            .applying(.init(paletteColors: [.white]))
        guard
            let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(style)
        else { return nil }
        let size = NSSize(width: Self.badgeSize, height: Self.badgeSize)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            glyph.draw(
                in: rect.insetBy(
                    dx: (rect.width - glyph.size.width) * Self.half,
                    dy: (rect.height - glyph.size.height) * Self.half))
            return true
        }
    }

    static func makeContextCapsule(_ icon: NSImageView, _ label: NSTextField) -> GlassView {
        let stack = NSStackView(views: [icon, label])
        stack.spacing = Self.actionGap
        return FloatingCapsule.make(
            stack, leading: Self.contextLeading, trailing: Self.contextTrailing)
    }
}
