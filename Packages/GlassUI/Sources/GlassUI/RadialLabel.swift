public import AppKit

@MainActor
public final class RadialLabel {
    private static let height: CGFloat = 26
    private static let inset: CGFloat = 12
    private static let gap: CGFloat = 6
    private static let fontSize: CGFloat = 12
    private static let half: CGFloat = 0.5

    public let panel = OverlayPanel()
    let text = FloatingCapsule.label(weight: .semibold, color: .labelColor)

    public init() {
        text.font = .systemFont(ofSize: Self.fontSize, weight: .semibold)
        let glass = FloatingCapsule.make(
            NSStackView(views: [text]), leading: Self.inset, trailing: Self.inset,
            height: Self.height, radius: Self.height * Self.half)
        let content = NSView()
        content.appearance = NSAppearance(named: .darkAqua)
        content.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            glass.topAnchor.constraint(equalTo: content.topAnchor),
            glass.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.staticText)
        panel.contentView = content
    }

    static func frame(width: CGFloat, below ring: NSRect, on screen: NSRect?) -> NSRect {
        var origin = NSPoint(
            x: (ring.midX - width * half).rounded(), y: ring.minY - gap - height)
        if let screen {
            if origin.y < screen.minY {
                origin.y = ring.maxY + gap
            }
            origin.x = min(max(origin.x, screen.minX), screen.maxX - width)
        }
        return NSRect(origin: origin, size: NSSize(width: width, height: height))
    }

    public func show(_ string: String, below ring: NSRect) {
        if text.stringValue != string {
            text.stringValue = string
            panel.contentView?.setAccessibilityLabel(string)
        }
        let centre = NSPoint(x: ring.midX, y: ring.midY)
        let screen = NSScreen.screens.first { NSMouseInRect(centre, $0.frame, false) }
        let width = panel.contentView?.fittingSize.width ?? 0
        panel.setFrame(Self.frame(width: width, below: ring, on: screen?.frame), display: true)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    public func hide() {
        panel.orderOut(nil)
    }
}
