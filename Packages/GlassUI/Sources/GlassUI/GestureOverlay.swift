public import AppCore
public import AppKit

@MainActor
public final class GestureOverlay {
    public enum Status: Equatable, Sendable {
        case move(held: Shortcut.Modifiers, display: Int, displays: Int)
        case resize(CGSize)
    }

    struct Text: Equatable {
        let symbol: String
        let title: String
        let detail: String
    }

    private static let radius: CGFloat = 16
    private static let border: CGFloat = 2
    private static let borderAlpha: CGFloat = 0.85
    private static let fillAlpha: CGFloat = 0.06
    private static let hairline: CGFloat = 0.5
    private static let hairlineAlpha: CGFloat = 0.3
    private static let margin: CGFloat = 1
    private static let hudGap: CGFloat = 18
    private static let hudHeight: CGFloat = 32
    private static let hudInset: CGFloat = 14
    private static let hudSpacing: CGFloat = 8
    private static let fontSize: CGFloat = 12.5
    private static let half: CGFloat = 0.5

    let outline = OverlayPanel()
    let hud = OverlayPanel()
    let icon = NSImageView()
    let title = FloatingCapsule.label(weight: .bold, color: .labelColor)
    let detail = FloatingCapsule.label(weight: .regular, color: .secondaryLabelColor)
    private var status: Status?

    public init() {
        makeOutline()
        makeHUD()
    }

    static func text(_ status: Status) -> Text {
        switch status {
        case let .move(held, display, displays):
            let keys = HotKeyLabel.symbols(held).joined(separator: " ") + " held"
            let screens = displays > 1 ? " · \(display) of \(displays) displays" : ""
            return Text(
                symbol: "arrow.up.and.down.and.arrow.left.and.right", title: "Move",
                detail: keys + screens)

        case .resize(let size):
            let width = Int(size.width.rounded())
            let height = Int(size.height.rounded())
            return Text(
                symbol: "arrow.down.left.and.arrow.up.right", title: "Resize",
                detail: "\(width) × \(height)")
        }
    }

    private func makeOutline() {
        let edge = NSView()
        edge.wantsLayer = true
        edge.layer?.cornerRadius = Self.radius + Self.margin
        edge.layer?.cornerCurve = .continuous
        edge.layer?.borderWidth = Self.hairline
        edge.layer?.borderColor = NSColor.black.withAlphaComponent(Self.hairlineAlpha).cgColor
        let frame = NSView()
        frame.wantsLayer = true
        frame.layer?.cornerRadius = Self.radius
        frame.layer?.cornerCurve = .continuous
        frame.layer?.borderWidth = Self.border
        frame.layer?.borderColor = NSColor.white.withAlphaComponent(Self.borderAlpha).cgColor
        frame.layer?.backgroundColor = NSColor.white.withAlphaComponent(Self.fillAlpha).cgColor
        frame.translatesAutoresizingMaskIntoConstraints = false
        edge.addSubview(frame)
        NSLayoutConstraint.activate([
            frame.leadingAnchor.constraint(equalTo: edge.leadingAnchor, constant: Self.margin),
            frame.trailingAnchor.constraint(equalTo: edge.trailingAnchor, constant: -Self.margin),
            frame.topAnchor.constraint(equalTo: edge.topAnchor, constant: Self.margin),
            frame.bottomAnchor.constraint(equalTo: edge.bottomAnchor, constant: -Self.margin),
        ])
        outline.contentView = edge
    }

    private func makeHUD() {
        icon.symbolConfiguration = .init(pointSize: Self.fontSize, weight: .medium)
        icon.contentTintColor = .labelColor
        title.font = .systemFont(ofSize: Self.fontSize, weight: .bold)
        detail.font = .monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .regular)
        let stack = NSStackView(views: [icon, title, detail])
        stack.spacing = Self.hudSpacing
        let glass = FloatingCapsule.make(
            stack, leading: Self.hudInset, trailing: Self.hudInset, height: Self.hudHeight,
            radius: Self.hudHeight * Self.half)
        let content = NSView()
        content.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            glass.topAnchor.constraint(equalTo: content.topAnchor),
            glass.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.staticText)
        hud.contentView = content
        hud.hasShadow = true
    }

    public func show(_ frame: CGRect, status: Status) {
        outline.setFrame(frame.insetBy(dx: -Self.margin, dy: -Self.margin), display: false)
        if status != self.status {
            self.status = status
            let text = Self.text(status)
            icon.image = NSImage(systemSymbolName: text.symbol, accessibilityDescription: nil)
            title.stringValue = text.title
            detail.stringValue = text.detail
            hud.contentView?.setAccessibilityLabel(
                HotKeyLabel.spoken(text: "\(text.title), \(text.detail)"))
        }
        placeHUD(below: frame)
        if !outline.isVisible {
            outline.orderFrontRegardless()
            hud.orderFrontRegardless()
        }
    }

    public func hide() {
        outline.orderOut(nil)
        hud.orderOut(nil)
        status = nil
    }

    private func placeHUD(below frame: CGRect) {
        let width = hud.contentView?.fittingSize.width ?? 0
        var origin = CGPoint(
            x: (frame.midX - width * Self.half).rounded(),
            y: frame.minY - Self.hudGap - Self.hudHeight)
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { NSMouseInRect(centre, $0.frame, false) }
        if let visible = screen?.visibleFrame {
            origin.x = min(
                max(origin.x, visible.minX + Self.hudGap), visible.maxX - Self.hudGap - width)
            origin.y = max(origin.y, visible.minY + Self.hudGap)
        }
        hud.setFrame(
            CGRect(origin: origin, size: CGSize(width: width, height: Self.hudHeight)),
            display: false)
    }
}
