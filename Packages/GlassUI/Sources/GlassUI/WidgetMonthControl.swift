import AppKit

final class WidgetMonthControl: NSView {
    enum Face {
        case symbol(String)
        case label(String)
    }

    static let height: CGFloat = 14
    private static let symbolWidth: CGFloat = 20
    private static let symbolSize: CGFloat = 8
    private static let labelSize: CGFloat = 9.5
    private static let labelKern: CGFloat = 0.3
    private static let labelPadding: CGFloat = 8
    private static let radius: CGFloat = 5
    private static let half: CGFloat = 0.5
    private static let sides: CGFloat = 2
    private static let hoverAlpha: CGFloat = 0.1
    private static let pillAlpha: CGFloat = 0.16
    private static let pillHoverAlpha: CGFloat = 0.3

    let width: CGFloat
    private let face: Face
    private let image: NSImage?
    private let text: NSAttributedString?
    var isShown = false
    var isHovered = false {
        didSet {
            if isHovered != oldValue { needsDisplay = true }
        }
    }

    override var isFlipped: Bool { true }

    init(_ face: Face) {
        self.face = face
        switch face {
        case .symbol(let name):
            image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: Self.symbolSize, weight: .bold))
            text = nil
            width = Self.symbolWidth

        case .label(let string):
            image = nil
            text = NSAttributedString(
                string: string.localizedUppercase,
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.labelSize, weight: .bold),
                    .foregroundColor: NSColor.controlAccentColor, .kern: Self.labelKern,
                ])
            width = (text?.size().width ?? 0).rounded(.up) + Self.labelPadding * Self.sides
        }
        super.init(frame: .zero)
        wantsLayer = true
        alphaValue = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        let pill = NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
        switch face {
        case .symbol:
            if isHovered {
                NSColor.labelColor.withAlphaComponent(Self.hoverAlpha).setFill()
                pill.fill()
            }

        case .label:
            NSColor.controlAccentColor
                .withAlphaComponent(isHovered ? Self.pillHoverAlpha : Self.pillAlpha).setFill()
            pill.fill()
        }
        if let text {
            let size = text.size()
            text.draw(
                at: NSPoint(
                    x: bounds.midX - size.width * Self.half,
                    y: bounds.midY - size.height * Self.half))
        } else if let image {
            tinted(image).draw(
                in: NSRect(
                    x: bounds.midX - image.size.width * Self.half,
                    y: bounds.midY - image.size.height * Self.half,
                    width: image.size.width, height: image.size.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                hints: nil)
        }
    }

    private func tinted(_ symbol: NSImage) -> NSImage {
        let colour = isHovered ? NSColor.labelColor : NSColor.secondaryLabelColor
        return NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            colour.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
