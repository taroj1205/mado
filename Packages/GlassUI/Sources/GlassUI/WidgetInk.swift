import AppKit

enum WidgetInk {
    struct Style {
        let size: CGFloat
        let weight: NSFont.Weight
        let colour: NSColor
        var digits = false
        var kern: CGFloat = 0
        var caps = false

        var attributes: [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            return [
                .font: digits
                    ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: colour, .kern: kern, .paragraphStyle: paragraph,
            ]
        }

        var height: CGFloat {
            ceil(NSAttributedString(string: "Ag", attributes: attributes).size().height)
        }

        func width(of text: String) -> CGFloat {
            ceil(NSAttributedString(string: shown(text), attributes: attributes).size().width)
        }

        func shown(_ text: String) -> String {
            caps ? text.localizedUppercase : text
        }
    }

    private static let half: CGFloat = 0.5
    private static let sizes = (
        caption: 10.0, hour: 10.5, hourValue: 12.5, fact: 12.0, gauge: 20.0, ring: 12.0,
        smallRing: 9.5
    )
    private static let captionKern: CGFloat = 0.4
    private static let gaugeKern: CGFloat = -0.3

    static let caption = Style(
        size: sizes.caption, weight: .semibold, colour: .secondaryLabelColor,
        kern: captionKern, caps: true)
    static let hourLabel = Style(size: sizes.hour, weight: .medium, colour: .secondaryLabelColor)
    static let hourNow = Style(size: sizes.hour, weight: .semibold, colour: .labelColor)
    static let hourValue = Style(
        size: sizes.hourValue, weight: .semibold, colour: .labelColor, digits: true)
    static let factValue = Style(
        size: sizes.fact, weight: .semibold, colour: .labelColor, digits: true)
    static let gaugeValue = Style(
        size: sizes.gauge, weight: .semibold, colour: .labelColor, digits: true,
        kern: gaugeKern)
    static let ringValue = Style(
        size: sizes.ring, weight: .semibold, colour: .labelColor, digits: true)
    static let smallRingValue = Style(
        size: sizes.smallRing, weight: .semibold, colour: .labelColor, digits: true)
    static let tint = NSColor.secondaryLabelColor

    static func draw(_ text: String, _ style: Style, in rect: NSRect) {
        draw(text, style, in: rect, align: .left)
    }

    static func draw(_ text: String, _ style: Style, in rect: NSRect, align: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = align
        var attributes = style.attributes
        attributes[.paragraphStyle] = paragraph
        let line = NSAttributedString(string: style.shown(text), attributes: attributes)
        let height = style.height
        line.draw(
            with: NSRect(
                x: rect.minX, y: rect.midY - height * half, width: rect.width, height: height),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    static func drawSymbol(
        _ name: String, size: CGFloat, colour: NSColor, centredIn rect: NSRect
    ) {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(.init(paletteColors: [colour]))
        guard
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
        else { return }
        let drawn = image.size
        image.draw(
            in: NSRect(
                x: rect.midX - drawn.width * half, y: rect.midY - drawn.height * half,
                width: drawn.width, height: drawn.height))
    }
}
