public import AppKit

@MainActor
public final class InputModeHUD {
    private static let visibleMilliseconds = 800
    static let height: CGFloat = 34
    static let gap: CGFloat = 8
    static let visibleFor: Duration = .milliseconds(visibleMilliseconds)
    private static let padding: CGFloat = 14
    private static let spacing: CGFloat = 8
    private static let glyphSize: CGFloat = 16
    private static let latinGlyphSize: CGFloat = 15
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 11.5
    private static let fadeDuration: TimeInterval = 0.2

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .capsule)
    let glyph = NSTextField(labelWithString: "")
    let title = InputModeHUD.label(size: titleSize, weight: .medium, color: .labelColor)
    let detail = InputModeHUD.label(
        size: detailSize, weight: .regular, color: .secondaryLabelColor)
    private let stack: NSStackView
    private var fade: Task<Void, Never>?

    public init() {
        stack = NSStackView(views: [glyph, title, detail])
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        let border = GlassBorder(
            radius: GlassView.Shape.capsule.radius(
                in: NSSize(width: Self.height, height: Self.height)))
        let content = NSView()
        for view in [stack, border] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                view.topAnchor.constraint(equalTo: content.topAnchor),
                view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        panel.glass.sheen.isHidden = true
        panel.glass.contentView = content
    }

    static func frame(of size: CGSize, below caret: CGRect, in visible: CGRect) -> CGRect {
        let below = caret.minY - gap - size.height
        let originY = below >= visible.minY ? below : caret.maxY + gap
        return CGRect(
            x: min(max(caret.minX, visible.minX), visible.maxX - size.width),
            y: min(max(originY, visible.minY), visible.maxY - size.height),
            width: size.width, height: size.height)
    }

    private static func label(
        size: CGFloat, weight: NSFont.Weight, color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    public func show(glyph: String, title: String, detail: String, below caret: CGRect) {
        self.glyph.stringValue = glyph
        self.glyph.font = .systemFont(
            ofSize: glyph.allSatisfy(\.isASCII) ? Self.latinGlyphSize : Self.glyphSize,
            weight: .bold)
        self.title.stringValue = title
        self.detail.stringValue = detail
        let size = CGSize(width: stack.fittingSize.width, height: Self.height)
        let screen =
            NSScreen.screens.first { $0.frame.contains(caret.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(origin: caret.origin, size: size)
        panel.setFrame(Self.frame(of: size, below: caret, in: visible), display: true)
        fade?.cancel()
        animate(to: 1, over: 0)
        panel.orderFrontRegardless()
        fade = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.visibleFor)
                try Task.checkCancellation()
                self?.animate(to: 0, over: Self.fadeDuration)
                try await Task.sleep(for: .seconds(Self.fadeDuration))
                self?.panel.orderOut(nil)
            } catch {
                return
            }
        }
    }

    private func animate(to alpha: CGFloat, over duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = alpha
        }
    }

    public func close() {
        fade?.cancel()
        panel.orderOut(nil)
    }
}
